//
//  ProfileModels.swift
//  ToneAtelier
//
//  Created by Codex on 5/1/26.
//

import Foundation

// TODO: userClient.fetchMyProfile 응답을 매핑한다.
struct ProfileSummary: Equatable, Sendable {
  var id: String
  var name: String
  var nickname: String
  var bio: String
  var avatarURL: String?
  var stats: [ProfileStat]
}

extension ProfileSummary {
  static let placeholder = ProfileSummary(
    id: "preview-profile",
    name: "YOON SESAC",
    nickname: "청록 새록",
    bio: "맑고 깊은 청록 톤으로 일상의 빛을 기록합니다.",
    avatarURL: nil,
    stats: [
      ProfileStat(value: "24", label: "FILTER"),
      ProfileStat(value: "8.2K", label: "LIKES"),
      ProfileStat(value: "132", label: "SAVED")
    ]
  )
}

struct ProfileStat: Identifiable, Equatable, Sendable {
  var value: String
  var label: String

  var id: String { label }
}

// TODO: filterClient.userFilters 응답을 likeCount desc로 정렬해 1개를 매핑한다.
struct FeaturedFilter: Identifiable, Equatable, Sendable {
  var id: String
  var name: String
  var meta: String
  var description: String
  var thumbnailURL: String?
}

extension FeaturedFilter {
  static let placeholder = FeaturedFilter(
    id: "preview-featured-filter",
    name: "청연",
    meta: "자연광 · 인물 · 12.4K 사용",
    description: "피부 톤을 부드럽게 정돈하는 시그니처 프리셋",
    thumbnailURL: nil
  )
}

// TODO: filterClient.likedFilters 응답 항목을 매핑한다.
struct LikedFilter: Identifiable, Equatable, Sendable {
  var id: String
  var title: String
  var likeCount: Int
  var coverURL: String?
}

extension LikedFilter {
  static let placeholders: [LikedFilter] = [
    LikedFilter(
      id: "preview-liked-1",
      title: "청연",
      likeCount: 12400,
      coverURL: nil
    ),
    LikedFilter(
      id: "preview-liked-2",
      title: "야간",
      likeCount: 8200,
      coverURL: nil
    )
  ]
}
