//
//  CreatorStoreFeature.swift
//  ToneAtelier
//
//  Created by Codex on 5/1/26.
//

import ComposableArchitecture
import Foundation

// TODO: 응답 추출 helper는 후속 브랜치에서 전용 Decodable DTO로 대체.

@Reducer
struct CreatorStoreFeature {
  @Dependency(\.userClient) var userClient
  @Dependency(\.filterClient) var filterClient

  @ObservableState
  struct State: Equatable {
    let userID: String
    let isOwn: Bool
    /// ProfileFeature가 미리 알고 있는 닉네임이 있으면 헤더에 즉시 표시한다.
    /// hero 로드 후에는 hero.nickname을 우선 사용.
    var headerName: String?
    var hero: CreatorStoreHero?
    var items: [CreatorStoreItem] = []
    var selectedTab: CreatorStoreFilterTab = .popular
    var isLoading = false
    var hasLoaded = false
    var errorMessage: String?
    var detail: HomeDetailFeature.State?
    /// 좋아요 토글 요청이 진행 중인 항목 id 집합. 동일 항목 중복 탭을 막고
    /// FeedListItemView의 `isLikeRequestInFlight` 표시에 사용한다.
    var likeRequestInFlightIDs: Set<CreatorStoreItem.ID> = []

    init(
      userID: String,
      isOwn: Bool,
      headerName: String? = nil
    ) {
      self.userID = userID
      self.isOwn = isOwn
      self.headerName = headerName
    }

    /// 정렬 탭 적용 결과. selectedTab에 따라 클라이언트 사이드 정렬을 수행한다.
    /// - popular: likeCount 내림차순
    /// - recent: createdAt 내림차순. createdAt이 없는 항목은 뒤로 밀어낸다.
    var sortedItems: [CreatorStoreItem] {
      switch selectedTab {
      case .popular:
        return items.sorted { $0.likeCount > $1.likeCount }
      case .recent:
        return items.sorted { lhs, rhs in
          switch (lhs.createdAt, rhs.createdAt) {
          case let (l?, r?): return l > r
          case (_?, nil): return true
          case (nil, _?): return false
          case (nil, nil): return false
          }
        }
      }
    }
  }

  struct LoadedStore: Equatable, Sendable {
    var hero: CreatorStoreHero
    var items: [CreatorStoreItem]
  }

  enum Action: Sendable {
    case task
    case retryButtonTapped
    case loadResponse(Result<LoadedStore, Error>)
    case tabSelected(CreatorStoreFilterTab)
    case rowTapped(CreatorStoreItem.ID)
    case likeButtonTapped(CreatorStoreItem.ID)
    case likeResponse(id: CreatorStoreItem.ID, previousIsLiked: Bool, previousLikeCount: Int, Result<Bool, Error>)
    // TODO: Make 화면 진입 후속 브랜치에서 연결.
    case createFilterButtonTapped
    case detail(HomeDetailFeature.Action)
    case detailDismissed
    case delegate(Delegate)

    enum Delegate: Equatable, Sendable {
      /// 작가 스토어 화면에서 좋아요 변동이 발생했음을 부모에게 전달.
      /// likeCount가 nil인 경우(서버 미보장)에는 토글 직후 클라가 추정한 값을 그대로 전달한다.
      case likeStatusChanged(CreatorStoreItem.ID, likeCount: Int?, isLiked: Bool)
    }
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .task:
        guard !state.isLoading, !state.hasLoaded else { return .none }
        return load(into: &state)

      case .retryButtonTapped:
        guard !state.isLoading else { return .none }
        return load(into: &state)

      case let .loadResponse(.success(loaded)):
        state.isLoading = false
        state.hasLoaded = true
        state.errorMessage = nil
        state.hero = loaded.hero
        state.items = loaded.items
        return .none

      case let .loadResponse(.failure(error)):
        state.isLoading = false
        state.hasLoaded = true
        state.errorMessage = error.userFacingMessage
        return .none

      case let .tabSelected(tab):
        state.selectedTab = tab
        return .none

      case let .rowTapped(id):
        guard let item = state.items.first(where: { $0.id == id }) else { return .none }
        state.detail = HomeDetailFeature.State(creatorStoreItem: item)
        return .none

      case let .likeButtonTapped(id):
        guard !state.likeRequestInFlightIDs.contains(id),
              let item = state.items.first(where: { $0.id == id }) else {
          return .none
        }

        let previousIsLiked = item.isLiked
        let previousLikeCount = item.likeCount
        let targetStatus = !previousIsLiked

        // Optimistic update — 작가 스토어는 좋아요 해제 시에도 항목을 유지하고 isLiked만 갈아끼운다.
        state.likeRequestInFlightIDs.insert(id)
        state.items = state.items.map { current in
          current.id == id ? current.settingLike(targetStatus, likeCount: nil) : current
        }
        let optimisticCount = state.items.first(where: { $0.id == id })?.likeCount ?? previousLikeCount
        let filterClient = self.filterClient

        return .merge(
          .send(.delegate(.likeStatusChanged(id, likeCount: optimisticCount, isLiked: targetStatus))),
          .run { send in
            await send(
              .likeResponse(
                id: id,
                previousIsLiked: previousIsLiked,
                previousLikeCount: previousLikeCount,
                Result { try await filterClient.setLike(id, targetStatus).like_status }
              )
            )
          }
          .cancellable(id: CancelID.like(id), cancelInFlight: true)
        )

      case let .likeResponse(id, _, _, .success(confirmedIsLiked)):
        state.likeRequestInFlightIDs.remove(id)
        state.items = state.items.map { current in
          current.id == id ? current.settingLike(confirmedIsLiked, likeCount: nil) : current
        }
        // 서버 확정 결과로 한 번 더 부모에게 동기화.
        let confirmedCount = state.items.first(where: { $0.id == id })?.likeCount
        return .send(.delegate(.likeStatusChanged(id, likeCount: confirmedCount, isLiked: confirmedIsLiked)))

      case let .likeResponse(id, previousIsLiked, previousLikeCount, .failure):
        state.likeRequestInFlightIDs.remove(id)
        state.items = state.items.map { current in
          current.id == id ? current.settingLike(previousIsLiked, likeCount: previousLikeCount) : current
        }
        return .send(.delegate(.likeStatusChanged(id, likeCount: previousLikeCount, isLiked: previousIsLiked)))

      case .createFilterButtonTapped:
        // TODO: Make 화면 진입 후속 브랜치에서 연결.
        return .none

      case let .detail(.delegate(.likeStatusChanged(id, isLiked, likeCount))):
        state.items = state.items.map { item in
          item.id == id ? item.settingLike(isLiked, likeCount: likeCount) : item
        }
        // 부모(ProfileFeature)가 마이 화면 미리보기를 동기화할 수 있도록 후속 yield.
        return .send(.delegate(.likeStatusChanged(id, likeCount: likeCount, isLiked: isLiked)))

      case .detail:
        return .none

      case .detailDismissed:
        state.detail = nil
        return .none

      case .delegate:
        return .none
      }
    }
    .ifLet(\.detail, action: \.detail) {
      HomeDetailFeature()
    }
  }

  private func load(into state: inout State) -> Effect<Action> {
    state.isLoading = true
    state.errorMessage = nil

    let userClient = self.userClient
    let filterClient = self.filterClient
    let userID = state.userID
    let presetHeaderName = state.headerName

    return .run { send in
      do {
        async let profileTask = userClient.fetchOtherProfile(userID)
        async let filtersTask = filterClient.userFilters(
          userID,
          UserFilterListQuery(next: nil, limit: 50, category: nil)
        )
        let profileJSON = try await profileTask
        let filtersJSON = try await filtersTask

        let items = CreatorStoreResponseParser.items(from: filtersJSON)
        let hero = CreatorStoreResponseParser.hero(
          from: profileJSON,
          fallbackName: presetHeaderName,
          filterCount: items.count
        )
        await send(.loadResponse(.success(LoadedStore(hero: hero, items: items))))
      } catch {
        await send(.loadResponse(.failure(error)))
      }
    }
    .cancellable(id: CancelID.load, cancelInFlight: true)
  }
}

// Reducer 외부에 두어 Sendable conformance가 main actor isolated되지 않도록 한다.
nonisolated private enum CancelID: Hashable, Sendable {
  case load
  case like(CreatorStoreItem.ID)
}

// MARK: - Response Parser

/// 작가 스토어 화면 전용 응답 파서. ProfileResponseParser/LikedFiltersResponseParser와 동일한
/// JSONValue 추출 패턴을 file-private로 복제. 후속 브랜치에서 전용 Decodable DTO로 통합 예정.
private enum CreatorStoreResponseParser {
  nonisolated static func hero(
    from value: JSONValue,
    fallbackName: String?,
    filterCount: Int
  ) -> CreatorStoreHero {
    let object = containerObject(from: value, preferredKeys: ["data", "user", "profile"])

    let nickname = object.firstString(for: ["nick", "nickname", "displayName"])
      ?? fallbackName?.trimmed.nilIfEmpty
      ?? "작품"
    let name = object.firstString(for: ["name", "fullName", "userName"])
    let introduction = object.firstString(for: ["introduction", "bio", "description", "intro"])
    let profileImage = object.firstString(for: [
      "profileImage",
      "profile_image",
      "image",
      "image_url",
      "imageUrl"
    ])

    return CreatorStoreHero(
      nickname: nickname,
      name: name,
      introduction: introduction,
      profileImageURL: profileImage,
      filterCount: filterCount
    )
  }

  nonisolated static func items(from value: JSONValue) -> [CreatorStoreItem] {
    let arrayItems = containerArray(from: value, preferredKeys: ["data", "filters", "items", "results", "list"])

    return arrayItems.enumerated().map { index, item in
      let object = containerObject(from: item, preferredKeys: ["filter", "item", "data"])

      let likeCount =
        object.firstInt(for: ["like_count", "likeCount", "likes_count", "likesCount"])
        ?? object["like_users"]?.arrayValue?.count
        ?? object["likes"]?.arrayValue?.count
        ?? 0

      let creatorObject = object["creator"]?.objectValue ?? [:]
      let author = creatorObject.firstString(for: ["nick", "name"])
        ?? object.firstString(for: ["author", "creator_nick", "creatorNick"])
        ?? ""

      let isLiked =
        object.firstBool(for: ["is_liked", "isLiked", "liked"])
        ?? false

      // id 폴백을 인덱스 기반("store-\(index)")에서 인덱스 + UUID prefix 조합으로 강화.
      // 페이지네이션 도입 시 페이지 간 인덱스 충돌로 동일 ID가 발생하는 것을 방지(Minor #20).
      let idFallback = "store-\(index)-\(UUID().uuidString.prefix(8))"

      return CreatorStoreItem(
        id: object.firstString(for: ["filter_id", "id", "_id", "uuid"], default: idFallback),
        title: object.firstString(for: ["title", "name", "filter_name"], default: "이름 없는 필터"),
        author: author,
        category: object.firstString(for: ["category", "categoryName", "category_name"]) ?? "",
        description: object.firstString(for: ["description", "introduction", "summary"]) ?? "",
        likeCount: likeCount,
        imageURL: object.primaryImagePath(),
        price: object.firstInt(for: ["price", "filter_price", "filterPrice"]),
        createdAt: object.firstString(for: ["createdAt", "created_at", "created", "registDate"]),
        isLiked: isLiked
      )
    }
  }

  nonisolated private static func containerArray(from value: JSONValue, preferredKeys: [String]) -> [JSONValue] {
    if let array = value.arrayValue {
      return array
    }

    guard let object = value.objectValue else { return [] }

    for key in preferredKeys {
      if let array = object[key]?.arrayValue {
        return array
      }
      if let nestedObject = object[key]?.objectValue {
        for nestedKey in preferredKeys where nestedKey != key {
          if let array = nestedObject[nestedKey]?.arrayValue {
            return array
          }
        }
      }
    }

    return []
  }

  nonisolated private static func containerObject(from value: JSONValue, preferredKeys: [String]) -> [String: JSONValue] {
    if let object = value.objectValue {
      for key in preferredKeys {
        if let nested = object[key]?.objectValue {
          return nested
        }
      }
      return object
    }

    if let first = value.arrayValue?.first?.objectValue {
      return first
    }

    return [:]
  }
}

private extension JSONValue {
  nonisolated
  var objectValue: [String: JSONValue]? {
    guard case let .object(object) = self else { return nil }
    return object
  }

  nonisolated
  var arrayValue: [JSONValue]? {
    guard case let .array(array) = self else { return nil }
    return array
  }

  nonisolated
  var stringValue: String? {
    switch self {
    case let .string(value):
      return value
    case let .number(value):
      return String(Int(value))
    default:
      return nil
    }
  }

  nonisolated
  var intValue: Int? {
    switch self {
    case let .number(value):
      return Int(value)
    case let .string(value):
      return Int(value)
    default:
      return nil
    }
  }

  nonisolated
  var boolValue: Bool? {
    switch self {
    case let .boolean(value):
      return value
    case let .string(value):
      switch value.lowercased() {
      case "true", "1": return true
      case "false", "0": return false
      default: return nil
      }
    case let .number(value):
      return value != 0
    default:
      return nil
    }
  }
}

private extension Dictionary where Key == String, Value == JSONValue {
  nonisolated
  func firstString(for keys: [String], default fallback: String) -> String {
    firstString(for: keys) ?? fallback
  }

  nonisolated
  func firstString(for keys: [String]) -> String? {
    for key in keys {
      if let value = self[key]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
        return value
      }
    }
    return nil
  }

  nonisolated
  func firstInt(for keys: [String]) -> Int? {
    for key in keys {
      if let value = self[key]?.intValue {
        return value
      }
    }
    return nil
  }

  nonisolated
  func firstBool(for keys: [String]) -> Bool? {
    for key in keys {
      if let value = self[key]?.boolValue {
        return value
      }
    }
    return nil
  }

  nonisolated
  func primaryImagePath() -> String? {
    firstString(for: [
      "image",
      "image_url",
      "imageUrl",
      "thumbnail",
      "thumbnailImage",
      "thumbnail_image",
      "profileImage",
      "profile_image"
    ]) ?? firstPrimaryString(in: ["files", "images", "galleryImages", "gallery_images"])
  }

  nonisolated
  private func firstPrimaryString(in keys: [String]) -> String? {
    for key in keys {
      if let value = self[key] {
        if let string = value.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines), !string.isEmpty {
          return string
        }
        if let array = value.arrayValue {
          for element in array {
            if let string = element.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines), !string.isEmpty {
              return string
            }
            if let object = element.objectValue,
               let string = object.firstString(for: [
                 "image",
                 "image_url",
                 "imageUrl",
                 "thumbnail",
                 "thumbnailImage",
                 "thumbnail_image",
                 "file",
                 "path"
               ]),
               !string.isEmpty {
              return string
            }
          }
        }
      }
    }
    return nil
  }
}

private extension String {
  nonisolated
  var nilIfEmpty: String? {
    isEmpty ? nil : self
  }
}

// MARK: - Error Mapping

private extension Error {
  var userFacingMessage: String {
    if let apiError = self as? APIError {
      switch apiError {
      case let .invalidBaseURL(message),
           let .invalidURL(message),
           let .transport(message),
           let .decoding(message):
        return message

      case .missingAccessToken, .missingRefreshToken:
        return "인증 정보가 없어 작품을 불러올 수 없어요."

      case let .invalidSession(statusCode):
        return "세션이 유효하지 않습니다. 다시 로그인해 주세요. (\(statusCode))"

      case let .server(statusCode, message, _):
        if let message, !message.isEmpty {
          return message
        }
        return "서버 응답을 불러오지 못했어요. (\(statusCode))"
      }
    }

    return "작품을 불러오지 못했어요. 잠시 후 다시 시도해 주세요."
  }
}
