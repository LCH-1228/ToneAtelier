//
//  ProfileResponseParser.swift
//  ToneAtelier
//
//  Created by Codex on 5/1/26.
//

import Foundation

// 마이 화면용 응답 파서. HomeClient의 file-private 추출 패턴을 동일하게 따른다.
// 후속 브랜치에서 전용 Decodable DTO로 통합 예정.
enum ProfileResponseParser {
  struct UserFilterListItem: Equatable, Sendable {
    var id: String
    var title: String
    var likeCount: Int
    var imageURL: String?
    var category: String?
    var sampleSubject: String?
  }

  nonisolated static func summary(
    from response: MyProfileResponse,
    userID: String,
    filterCount: Int,
    likedCount: Int,
    totalLikes: Int
  ) -> ProfileSummary {
    let nickname = response.nick.trimmed
    let displayName = response.name?.trimmed.nilIfEmpty ?? nickname
    let introduction = response.introduction?.trimmed.nilIfEmpty
      ?? "소개 글을 작성해 보세요."
    let avatarURL = response.profileImage?.trimmed.nilIfEmpty
    let email = response.email?.trimmed.nilIfEmpty ?? ""
    let phoneNum = response.phoneNum?.trimmed.nilIfEmpty
    let hashTags = response.hashTags ?? []

    return ProfileSummary(
      id: userID.isEmpty ? response.user_id : userID,
      name: displayName,
      nickname: nickname,
      bio: introduction,
      avatarURL: avatarURL,
      email: email,
      phoneNum: phoneNum,
      hashTags: hashTags,
      stats: [
        ProfileStat(value: String(filterCount), label: "FILTER"),
        ProfileStat(value: String(totalLikes), label: "LIKES"),
        ProfileStat(value: String(likedCount), label: "SAVED")
      ]
    )
  }

  nonisolated static func userFilterListItems(from value: JSONValue) -> [UserFilterListItem] {
    let items = containerArray(from: value, preferredKeys: ["data", "filters", "items", "results", "list"])

    return items.enumerated().map { index, item in
      let object = containerObject(from: item, preferredKeys: ["filter", "item", "data"])

      let likeCount =
        object.firstInt(for: ["like_count", "likeCount", "likes_count", "likesCount"])
        ?? object["like_users"]?.arrayValue?.count
        ?? object["likes"]?.arrayValue?.count
        ?? 0

      return UserFilterListItem(
        id: object.firstString(for: ["filter_id", "id", "_id", "uuid"], default: "user-filter-\(index)"),
        title: object.firstString(for: ["title", "name", "filter_name"], default: "이름 없는 필터"),
        likeCount: likeCount,
        imageURL: object.primaryImagePath(),
        category: object.firstString(for: ["category", "categoryName", "category_name"]),
        sampleSubject: object.firstString(for: ["subject", "sample_subject", "sampleSubject", "person_type", "personType"])
      )
    }
  }

  nonisolated static func featuredFilter(from item: UserFilterListItem) -> FeaturedFilter {
    let metaTokens = [
      item.category,
      item.sampleSubject,
      item.likeCount > 0 ? "\(formattedCount(item.likeCount)) 사용" : nil
    ]
      .compactMap { $0?.trimmed.nilIfEmpty }

    let meta = metaTokens.isEmpty ? "대표 필터" : metaTokens.joined(separator: " · ")

    return FeaturedFilter(
      id: item.id,
      name: item.title,
      meta: meta,
      description: "지금 가장 많은 사랑을 받는 시그니처 프리셋",
      thumbnailURL: item.imageURL
    )
  }

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

      // 좋아한 목록 응답이라 사실상 항상 true이지만, 서버가 키를 명시하면 우선 신뢰.
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

  nonisolated private static func formattedCount(_ count: Int) -> String {
    String(count)
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
