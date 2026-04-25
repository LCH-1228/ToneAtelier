//
//  HomeClient.swift
//  ToneAtelier
//
//  Created by Codex on 4/24/26.
//

import ComposableArchitecture
import Foundation

struct HomeClient {
  var fetchHomeContent: @Sendable () async throws -> HomeScreenContent
}

extension HomeClient: DependencyKey {
  static var liveValue: HomeClient {
    @Dependency(\.bannerClient) var bannerClient
    @Dependency(\.filterClient) var filterClient
    @Dependency(\.userClient) var userClient

    return HomeClient(
      fetchHomeContent: {
        async let bannerResponse = bannerClient.fetchMainBanners()
        async let featuredFilterResponse = filterClient.todayFilter()
        async let hotTrendResponse = filterClient.hotTrend()
        async let todayAuthorResponse = userClient.fetchTodayAuthor()

        let featuredFilter = HomeResponseParser.featuredFilter(
          from: try await featuredFilterResponse
        )
        let banners = HomeResponseParser.banners(
          from: try await bannerResponse
        )
        let hotTrends = HomeResponseParser.hotTrends(
          from: try await hotTrendResponse
        )
        let featuredAuthor = HomeResponseParser.author(
          from: try await todayAuthorResponse
        )

        return HomeScreenContent(
          featuredFilter: featuredFilter,
          banners: banners,
          hotTrends: hotTrends,
          featuredAuthor: featuredAuthor
        )
      }
    )
  }

  static let testValue = HomeClient(
    fetchHomeContent: {
      throw APIError.transport("HomeClient.fetchHomeContent testValue")
    }
  )
}

extension DependencyValues {
  var homeClient: HomeClient {
    get { self[HomeClient.self] }
    set { self[HomeClient.self] = newValue }
  }
}

private enum HomeResponseParser {
  nonisolated static func featuredFilter(from value: JSONValue) -> HomeFeaturedFilter? {
    let object = containerObject(from: value, preferredKeys: ["data", "filter", "item", "todayFilter"])
    let title = object.firstString(
      for: ["title", "name", "filter_name", "filterName"],
      default: "오늘의 추천 필터"
    )
    let summary = object.firstString(
      for: ["description", "summary", "content", "introduction"],
      default: "필터 설명이 아직 준비되지 않았어요."
    )
    let imageURL = object.primaryImagePath()

    return HomeFeaturedFilter(
      id: object.firstString(for: ["filter_id", "id", "_id", "uuid"], default: UUID().uuidString),
      title: title,
      summary: summary,
      imageURL: imageURL
    )
  }

  nonisolated static func banners(from value: JSONValue) -> [HomeBanner] {
    let items = containerArray(from: value, preferredKeys: ["data", "banners", "items", "results"])

    return items.enumerated().map { index, item in
      let object = containerObject(from: item, preferredKeys: ["banner", "item", "data"])
      return HomeBanner(
        id: object.firstString(for: ["banner_id", "id", "_id", "uuid"], default: "banner-\(index)"),
        title: object.firstString(for: ["name", "title"], default: "배너 \(index + 1)"),
        imageURL: object.primaryImagePath(),
        payload: object.primaryBannerPayload()
      )
    }
  }

  nonisolated static func hotTrends(from value: JSONValue) -> [HomeTrend] {
    let items = containerArray(from: value, preferredKeys: ["data", "filters", "items", "results", "list"])

    return items.enumerated().map { index, item in
      let object = containerObject(from: item, preferredKeys: ["filter", "item", "data"])

      let likeCount =
        object.firstInt(for: ["like_count", "likeCount", "likes_count", "likesCount"])
        ?? object["like_users"]?.arrayValue?.count
        ?? object["likes"]?.arrayValue?.count
        ?? 0

      return HomeTrend(
        id: object.firstString(for: ["filter_id", "id", "_id", "uuid"], default: "trend-\(index)"),
        title: object.firstString(for: ["title", "name", "filter_name"], default: "이름 없는 필터"),
        likeCount: likeCount,
        imageURL: object.primaryImagePath()
      )
    }
  }

  nonisolated static func author(from value: JSONValue) -> HomeAuthor? {
    let rootObject = containerObject(from: value, preferredKeys: ["data", "author", "user", "profile"])
    let authorObject = rootObject.primaryNestedObject(for: ["author", "user", "profile"]) ?? rootObject

    let name = authorObject.firstString(for: ["nick", "name", "displayName"], default: "오늘의 작가")
    let subtitle = authorObject.firstString(
      for: ["english_name", "englishName", "name_en", "nameEn"],
      default: name.uppercased()
    )
    let portraitURL = authorObject.primaryImagePath()
    let tags = authorObject.primaryTagValues().prefix(3).map { "#\($0)" }

    let quoteSource = authorObject.firstString(
      for: ["quote", "summary", "tagline", "bio"],
      default: "감도 높은 결과를 만드는 필터 크리에이터"
    )
    let quote = quoteSource.hasPrefix("\"") ? quoteSource : "\"\(quoteSource)\""

    let description = authorObject.firstString(
      for: ["introduction", "description", "about", "bio"],
      default: "작가 소개가 아직 준비되지 않았어요."
    )

    return HomeAuthor(
      id: authorObject.firstString(for: ["user_id", "id", "_id", "uuid"], default: UUID().uuidString),
      name: name,
      subtitle: subtitle,
      portraitURL: portraitURL,
      galleryImageURLs: galleryImageURLs(from: rootObject, authorObject: authorObject),
      tags: Array(tags),
      quote: quote,
      description: description
    )
  }

  nonisolated private static func galleryImageURLs(
    from rootObject: [String: JSONValue],
    authorObject: [String: JSONValue]
  ) -> [String] {
    let directGallery = authorObject.primaryImagePaths(for: [
      "galleryImages",
      "gallery_images",
      "portfolioImages",
      "portfolio_images",
      "images",
      "files"
    ])

    if !directGallery.isEmpty {
      return Array(directGallery.prefix(3))
    }

    let nestedCollections = [
      rootObject["filters"]?.arrayValue,
      rootObject["items"]?.arrayValue,
      rootObject["works"]?.arrayValue,
      rootObject["portfolio"]?.arrayValue,
      rootObject["portfolioItems"]?.arrayValue,
      rootObject["data"]?.objectValue?["filters"]?.arrayValue,
    ]

    for collection in nestedCollections.compactMap({ $0 }) {
      let urls = collection.compactMap { item -> String? in
        let object = containerObject(from: item, preferredKeys: ["filter", "item", "data"])
        return object.primaryImagePath()
      }

      if !urls.isEmpty {
        return Array(urls.prefix(3))
      }
    }

    return []
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
  func primaryNestedObject(for keys: [String]) -> [String: JSONValue]? {
    for key in keys {
      if let object = self[key]?.objectValue {
        return object
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
      "bannerImage",
      "banner_image",
      "thumbnail",
      "thumbnailImage",
      "thumbnail_image",
      "profileImage",
      "profile_image"
    ]) ?? firstPrimaryString(in: ["files", "images", "galleryImages", "gallery_images"])
  }

  nonisolated
  func primaryImagePaths(for keys: [String]) -> [String] {
    for key in keys {
      if let array = self[key]?.arrayValue {
        let strings = array.compactMap(\.stringValue).filter { !$0.isEmpty }
        if !strings.isEmpty {
          return strings
        }
      }
    }
    return []
  }

  nonisolated
  func primaryTagValues() -> [String] {
    let keys = ["hashTags", "hashtags", "tags"]

    for key in keys {
      if let array = self[key]?.arrayValue {
        let strings = array.compactMap { value -> String? in
          if let string = value.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines), !string.isEmpty {
            return string.replacingOccurrences(of: "#", with: "")
          }
          if let object = value.objectValue,
             let string = object.firstString(for: ["name", "title", "value"]),
             !string.isEmpty {
            return string.replacingOccurrences(of: "#", with: "")
          }
          return nil
        }

        if !strings.isEmpty {
          return strings
        }
      }
    }

    return []
  }

  nonisolated
  func primaryBannerPayload() -> HomeBannerPayload? {
    guard let payload = self["payload"]?.objectValue else { return nil }
    guard let typeValue = payload.firstString(for: ["type"]),
          let type = HomeBannerPayloadType(rawValue: typeValue.uppercased()),
          let value = payload.firstString(for: ["value", "url", "path"]) else {
      return nil
    }

    return HomeBannerPayload(type: type, value: value)
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
