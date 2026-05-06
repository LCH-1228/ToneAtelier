//
//  ProfileResponseParser.swift
//  ToneAtelier
//
//  Created by Codex on 5/1/26.
//

import Foundation

// 마이 화면용 응답 파서. spec FilterSummaryResponseDTO 기반으로 직접 매핑한다.
enum ProfileResponseParser {
  struct UserFilterListItem: Equatable, Sendable {
    var id: String
    var title: String
    var likeCount: Int
    var imageURL: String?
    var category: String?
    var sampleSubject: String?
    var authorUserID: String
  }

  nonisolated static func summary(
    from response: MyInfoResponseDTO,
    userID: String,
    filterCount: Int,
    postCount: Int,
    likedCount: Int
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
      id: userID.isEmpty ? response.userID : userID,
      name: displayName,
      nickname: nickname,
      bio: introduction,
      avatarURL: avatarURL,
      email: email,
      phoneNum: phoneNum,
      hashTags: hashTags,
      stats: [
        ProfileStat(value: String(filterCount), label: "FILTER"),
        ProfileStat(value: String(postCount), label: "POST"),
        ProfileStat(value: String(likedCount), label: "LIKE")
      ]
    )
  }

  nonisolated static func userFilterListItems(
    from items: [FilterSummaryResponseDTO]
  ) -> [UserFilterListItem] {
    items.map { item in
      UserFilterListItem(
        id: item.filterID,
        title: item.title,
        likeCount: item.likeCount,
        imageURL: item.files.first?.trimmed.nilIfEmpty,
        category: item.category?.trimmed.nilIfEmpty,
        sampleSubject: nil,
        authorUserID: item.creator.userID
      )
    }
  }

  nonisolated static func featuredFilter(from item: UserFilterListItem) -> FeaturedFilter {
    let metaTokens = [
      item.category,
      item.sampleSubject,
      item.likeCount > 0 ? "좋아요 \(item.likeCount)" : nil
    ]
      .compactMap { $0?.trimmed.nilIfEmpty }

    let meta = metaTokens.isEmpty ? "대표 필터" : metaTokens.joined(separator: " · ")

    return FeaturedFilter(
      id: item.id,
      name: item.title,
      meta: meta,
      description: "지금 가장 많은 사랑을 받는 시그니처 프리셋",
      thumbnailURL: item.imageURL,
      authorUserID: item.authorUserID
    )
  }

  nonisolated static func likedFilters(
    from items: [FilterSummaryResponseDTO]
  ) -> [LikedFilter] {
    items.map { item in
      LikedFilter(
        id: item.filterID,
        title: item.title,
        author: item.creator.nick,
        authorUserID: item.creator.userID,
        category: item.category ?? "",
        description: item.description,
        likeCount: item.likeCount,
        coverURL: item.files.first?.trimmed.nilIfEmpty,
        // likedFilters 응답은 사실상 항상 true이지만 spec 키를 그대로 신뢰.
        isLiked: item.isLiked
      )
    }
  }
}

private extension String {
  nonisolated var nilIfEmpty: String? { isEmpty ? nil : self }
}
