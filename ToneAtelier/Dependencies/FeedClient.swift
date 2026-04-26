//
//  FeedClient.swift
//  ToneAtelier
//
//  Created by Codex on 4/25/26.
//

import ComposableArchitecture
import Foundation

struct FeedClient {
  var fetchFeedContent: @Sendable (_ category: HomeCategory?) async throws -> FeedScreenContent
  var fetchFilterPage: @Sendable (_ category: HomeCategory?, _ nextCursor: String) async throws -> FeedFilterPage
  var setFilterLike: @Sendable (_ filterID: FeedFilterItem.ID, _ likeStatus: Bool) async throws -> Void
}

extension FeedClient: DependencyKey {
  static var liveValue: FeedClient {
    @Dependency(\.filterClient) var filterClient

    let fetchFilterPage: @Sendable (HomeCategory?, String) async throws -> FeedFilterPage = { category, nextCursor in
      let response = try await filterClient.list(
        FilterListQuery(
          next: nextCursor,
          limit: 5,
          category: category?.rawValue
        )
      )

      return FeedFilterPage(
        items: FeedResponseParser.filterItems(
          from: response,
          fallbackCategory: category
        ),
        nextCursor: FeedResponseParser.nextCursor(from: response)
      )
    }

    return FeedClient(
      fetchFeedContent: { category in
        async let rankingResponse = filterClient.hotTrend()
        async let filterPage = fetchFilterPage(category, "")

        let (rankingResponseValue, filterPageValue) = try await (rankingResponse, filterPage)

        let rankingItems = FeedResponseParser.rankingItems(
          from: rankingResponseValue,
          fallbackCategory: category
        )

        return FeedScreenContent(
          rankingItems: rankingItems,
          filterItems: filterPageValue.items,
          nextCursor: filterPageValue.nextCursor
        )
      },
      fetchFilterPage: fetchFilterPage,
      setFilterLike: { filterID, likeStatus in
        _ = try await filterClient.setLike(filterID, likeStatus)
      }
    )
  }

  static let testValue = FeedClient(
    fetchFeedContent: { _ in
      throw APIError.transport("FeedClient.fetchFeedContent testValue")
    },
    fetchFilterPage: { _, _ in
      throw APIError.transport("FeedClient.fetchFilterPage testValue")
    },
    setFilterLike: { _, _ in
      throw APIError.transport("FeedClient.setFilterLike testValue")
    }
  )
}

extension DependencyValues {
  var feedClient: FeedClient {
    get { self[FeedClient.self] }
    set { self[FeedClient.self] = newValue }
  }
}

private enum FeedResponseParser {
  nonisolated static func rankingItems(
    from value: JSONValue,
    fallbackCategory: HomeCategory?
  ) -> [FeedRankingItem] {
    let items = containerArray(from: value, preferredKeys: ["data", "filters", "items", "results", "list"])

    return items.enumerated().map { index, item in
      let object = containerObject(from: item, preferredKeys: ["filter", "item", "data"])

      return FeedRankingItem(
        id: object.firstString(for: ["filter_id", "id", "_id", "uuid"], default: "ranking-\(index)"),
        rank: index + 1,
        author: object.authorName(default: "SESAC"),
        title: object.firstString(for: ["title", "name", "filter_name", "filterName"], default: "이름 없는 필터"),
        category: object.displayCategory(fallback: fallbackCategory),
        imageURL: object.primaryImagePath()
      )
    }
  }

  nonisolated static func filterItems(
    from value: JSONValue,
    fallbackCategory: HomeCategory?
  ) -> [FeedFilterItem] {
    let items = containerArray(from: value, preferredKeys: ["data", "filters", "items", "results", "list"])

    return items.enumerated().map { index, item in
      let object = containerObject(from: item, preferredKeys: ["filter", "item", "data"])
      let likeCount =
        object.firstInt(for: ["like_count", "likeCount", "likes_count", "likesCount"])
        ?? object["like_users"]?.arrayValue?.count
        ?? object["likes"]?.arrayValue?.count
        ?? 0

      return FeedFilterItem(
        id: object.firstString(for: ["filter_id", "id", "_id", "uuid"], default: "filter-\(index)"),
        title: object.firstString(for: ["title", "name", "filter_name", "filterName"], default: "이름 없는 필터"),
        author: object.authorName(default: "SESAC"),
        category: object.displayCategory(fallback: fallbackCategory),
        description: object.firstString(
          for: ["description", "summary", "content", "introduction"],
          default: "필터 설명이 아직 준비되지 않았어요."
        ),
        likeCount: likeCount,
        isLiked: object.firstBool(for: ["like_status", "likeStatus", "is_liked", "isLiked"], default: false),
        imageURL: object.primaryImagePath()
      )
    }
  }

  nonisolated static func nextCursor(from value: JSONValue) -> String {
    guard let object = value.objectValue else { return "0" }

    if let cursor = object.firstString(for: ["next_cursor", "nextCursor"]) {
      return cursor
    }

    if let nestedObject = object["data"]?.objectValue,
       let cursor = nestedObject.firstString(for: ["next_cursor", "nextCursor"]) {
      return cursor
    }

    return "0"
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
        for nestedKey in preferredKeys {
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
      return Bool(value)
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
  func firstBool(for keys: [String], default fallback: Bool) -> Bool {
    for key in keys {
      if let value = self[key]?.boolValue {
        return value
      }
    }
    return fallback
  }

  nonisolated
  func primaryImagePath() -> String? {
    firstString(for: [
      "image",
      "image_url",
      "imageUrl",
      "thumbnail",
      "thumbnailImage",
      "thumbnail_image"
    ]) ?? firstPrimaryString(in: ["files", "images", "galleryImages", "gallery_images"])
  }

  nonisolated
  func authorName(default fallback: String) -> String {
    if let direct = firstString(for: ["nick", "creator", "author", "user", "user_nick", "userNick"]) {
      return direct.uppercased()
    }

    for key in ["creator", "author", "user", "profile"] {
      if let object = self[key]?.objectValue,
         let name = object.firstString(for: ["nick", "name", "displayName", "user_nick", "userNick"]) {
        return name.uppercased()
      }
    }

    return fallback
  }

  nonisolated
  func displayCategory(fallback: HomeCategory?) -> String {
    guard let rawCategory = firstString(for: ["category", "category_name", "categoryName"]) else {
      return fallback.map { "#\($0.title)" } ?? "#필터"
    }

    let normalized = rawCategory.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    if let category = HomeCategory(rawValue: normalized) {
      return "#\(category.title)"
    }
    if let category = HomeCategory.allCases.first(where: { $0.title == normalized }) {
      return "#\(category.title)"
    }
    return normalized.isEmpty ? (fallback.map { "#\($0.title)" } ?? "#필터") : "#\(normalized)"
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
