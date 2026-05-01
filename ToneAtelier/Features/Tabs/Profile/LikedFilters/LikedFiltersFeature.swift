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
  }

  enum Action: Sendable {
    case task
    case retryButtonTapped
    case itemsResponse(Result<[LikedFilter], Error>)
    case rowTapped(LikedFilter.ID)
    case detail(HomeDetailFeature.Action)
    case detailDismissed
    case delegate(Delegate)

    enum Delegate: Equatable, Sendable {
      /// 좋아하는 필터 화면에서 좋아요 변동이 발생했음을 부모(ProfileFeature)에 알린다.
      /// likeCount가 nil인 경우(서버 미보장)에는 토글 직후 클라가 추정한 값을 그대로 전달한다.
      case likeStatusChanged(LikedFilter.ID, likeCount: Int?)
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

      case let .detail(.delegate(.likeStatusChanged(id, _, likeCount))):
        state.items = state.items.map { item in
          item.id == id ? item.settingLikeCount(likeCount) : item
        }
        // 부모(ProfileFeature)가 마이 화면 미리보기를 동기화할 수 있도록 후속 yield.
        return .send(.delegate(.likeStatusChanged(id, likeCount: likeCount)))

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

      return LikedFilter(
        id: object.firstString(for: ["filter_id", "id", "_id", "uuid"], default: "liked-\(index)"),
        title: object.firstString(for: ["title", "name", "filter_name"], default: "이름 없는 필터"),
        author: author,
        category: object.firstString(for: ["category", "categoryName", "category_name"]) ?? "",
        description: object.firstString(for: ["description", "introduction", "summary"]) ?? "",
        likeCount: likeCount,
        coverURL: object.primaryImagePath()
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
