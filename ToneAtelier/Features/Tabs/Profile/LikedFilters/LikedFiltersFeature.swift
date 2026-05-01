//
//  LikedFiltersFeature.swift
//  ToneAtelier
//
//  Created by Codex on 5/1/26.
//

import ComposableArchitecture
import Foundation

// TODO: 응답 추출 helper는 후속 브랜치에서 전용 Decodable DTO로 대체.

@Reducer
struct LikedFiltersFeature {
  @Dependency(\.filterClient) var filterClient

  @ObservableState
  struct State: Equatable {
    var items: [LikedFilter] = []
    var isLoading = false
    var hasLoaded = false
    var errorMessage: String?
    var detail: HomeDetailFeature.State?
    /// 좋아요 토글 요청이 진행 중인 항목 id 집합. 동일 항목 중복 탭을 막고
    /// FeedListItemView의 `isLikeRequestInFlight` 표시에 사용한다.
    var likeRequestInFlightIDs: Set<LikedFilter.ID> = []
  }

  enum Action: Sendable {
    case task
    case retryButtonTapped
    case itemsResponse(Result<[LikedFilter], Error>)
    case rowTapped(LikedFilter.ID)
    case likeButtonTapped(LikedFilter.ID)
    case likeResponse(id: LikedFilter.ID, previousIsLiked: Bool, previousLikeCount: Int, Result<Bool, Error>)
    case detail(HomeDetailFeature.Action)
    case detailDismissed
    case delegate(Delegate)

    enum Delegate: Equatable, Sendable {
      /// 좋아하는 필터 화면에서 좋아요 변동이 발생했음을 부모(ProfileFeature)에 알린다.
      /// likeCount가 nil인 경우(서버 미보장)에는 토글 직후 클라가 추정한 값을 그대로 전달한다.
      case likeStatusChanged(LikedFilter.ID, likeCount: Int?, isLiked: Bool)
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

      case let .itemsResponse(.success(items)):
        state.isLoading = false
        state.hasLoaded = true
        state.errorMessage = nil
        state.items = items
        return .none

      case let .itemsResponse(.failure(error)):
        state.isLoading = false
        state.hasLoaded = true
        state.errorMessage = error.userFacingMessage
        return .none

      case let .rowTapped(id):
        guard let filter = state.items.first(where: { $0.id == id }) else { return .none }
        state.detail = HomeDetailFeature.State(likedFilter: filter)
        return .none

      case let .likeButtonTapped(id):
        // 진행 중이거나 항목이 사라진 경우 무시.
        guard !state.likeRequestInFlightIDs.contains(id),
              let item = state.items.first(where: { $0.id == id }) else {
          return .none
        }

        let previousIsLiked = item.isLiked
        let previousLikeCount = item.likeCount
        let targetStatus = !previousIsLiked

        // 1) Optimistic update — UI 즉시 반영.
        state.likeRequestInFlightIDs.insert(id)
        state.items = state.items.map { current in
          current.id == id ? current.settingLike(targetStatus, likeCount: nil) : current
        }

        // 2) 부모 미리보기도 동시 동기화(롤백 시 likeResponse 실패 분기에서 재yield).
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
          .cancellable(id: "LikedFiltersFeature.like.\(id)", cancelInFlight: true)
        )

      case let .likeResponse(id, _, _, .success(confirmedIsLiked)):
        state.likeRequestInFlightIDs.remove(id)

        if confirmedIsLiked {
          // 정상 토글 결과가 true 그대로 — items 상태는 optimistic update와 동일하므로 유지.
          // 다만 likeCount는 서버 응답이 없으므로 그대로 두고, 부모에게 한 번 더 동기화 신호.
          let currentCount = state.items.first(where: { $0.id == id })?.likeCount
          return .send(.delegate(.likeStatusChanged(id, likeCount: currentCount, isLiked: true)))
        } else {
          // 좋아요 해제가 확정 — "좋아한 목록"에서 제거.
          state.items.removeAll { $0.id == id }
          return .send(.delegate(.likeStatusChanged(id, likeCount: nil, isLiked: false)))
        }

      case let .likeResponse(id, previousIsLiked, previousLikeCount, .failure):
        state.likeRequestInFlightIDs.remove(id)
        // Optimistic update 롤백.
        state.items = state.items.map { current in
          current.id == id ? current.settingLike(previousIsLiked, likeCount: previousLikeCount) : current
        }
        // 부모 미리보기도 롤백된 값으로 재동기화.
        return .send(.delegate(.likeStatusChanged(id, likeCount: previousLikeCount, isLiked: previousIsLiked)))

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

    let filterClient = self.filterClient

    return .run { send in
      do {
        let json = try await filterClient.likedFilters(
          UserFilterListQuery(next: nil, limit: 50, category: nil)
        )
        let items = LikedFiltersResponseParser.likedFilters(from: json)
        await send(.itemsResponse(.success(items)))
      } catch {
        await send(.itemsResponse(.failure(error)))
      }
    }
    .cancellable(id: "LikedFiltersFeature.load", cancelInFlight: true)
  }
}

// MARK: - Response Parser

// 좋아하는 필터 화면 전용 응답 파서. ProfileResponseParser.likedFilters의 추출 로직을
// 동일하게 복제. 후속 브랜치에서 전용 Decodable DTO로 통합 예정.
private enum LikedFiltersResponseParser {
  nonisolated static func likedFilters(from value: JSONValue) -> [LikedFilter] {
    let items = containerArray(from: value, preferredKeys: ["data", "filters", "items", "results", "list"])

    return items.enumerated().map { index, item in
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

      // 좋아한 목록 API 응답이라 사실상 항상 true이지만, 서버 키가 있으면 우선 신뢰.
      let isLiked = object.firstBool(for: ["is_liked", "isLiked", "liked"]) ?? true

      // id 폴백을 인덱스 기반("liked-\(index)")에서 인덱스 + UUID prefix 조합으로 강화.
      // 페이지네이션 도입 시 페이지 간 인덱스 충돌로 동일 ID가 발생하는 것을 방지(Minor #20).
      let idFallback = "liked-\(index)-\(UUID().uuidString.prefix(8))"

      return LikedFilter(
        id: object.firstString(for: ["filter_id", "id", "_id", "uuid"], default: idFallback),
        title: object.firstString(for: ["title", "name", "filter_name"], default: "이름 없는 필터"),
        author: author,
        category: object.firstString(for: ["category", "categoryName", "category_name"]) ?? "",
        description: object.firstString(for: ["description", "introduction", "summary"]) ?? "",
        likeCount: likeCount,
        coverURL: object.primaryImagePath(),
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
        return "인증 정보가 없어 좋아하는 필터를 불러올 수 없어요."

      case let .invalidSession(statusCode):
        return "세션이 유효하지 않습니다. 다시 로그인해 주세요. (\(statusCode))"

      case let .server(statusCode, message, _):
        if let message, !message.isEmpty {
          return message
        }
        return "서버 응답을 불러오지 못했어요. (\(statusCode))"
      }
    }

    return "좋아하는 필터를 불러오지 못했어요. 잠시 후 다시 시도해 주세요."
  }
}
