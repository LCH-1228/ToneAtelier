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
  /// 프로필 편집 화면 초기값 용도. 마이 화면 본체 UI에서는 노출하지 않는다.
  var email: String
  var phoneNum: String?
  var hashTags: [String]
  var stats: [ProfileStat]
}

extension ProfileSummary {
  static let placeholder = ProfileSummary(
    id: "preview-profile",
    name: "YOON SESAC",
    nickname: "청록 새록",
    bio: "맑고 깊은 청록 톤으로 일상의 빛을 기록합니다.",
    avatarURL: nil,
    email: "preview@sesac.com",
    phoneNum: nil,
    hashTags: ["#맑음"],
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
  var author: String
  var category: String
  var description: String
  var likeCount: Int
  var coverURL: String?
}

extension LikedFilter {
  /// HomeDetail에서 좋아요 변동을 받았을 때 카운트만 갈아끼우기 위한 헬퍼.
  /// HomeTrend.settingLikeCount 패턴을 모방한다.
  func settingLikeCount(_ newCount: Int?) -> LikedFilter {
    guard let newCount, newCount != likeCount else { return self }
    var copy = self
    copy.likeCount = newCount
    return copy
  }

  static let placeholders: [LikedFilter] = [
    LikedFilter(
      id: "preview-liked-1",
      title: "청연",
      author: "YOON SESAC",
      category: "인물",
      description: "푸르른 여운처럼 마음에 스며드는, 고요하고 깊은 감성의 청록빛 필터.",
      likeCount: 12400,
      coverURL: nil
    ),
    LikedFilter(
      id: "preview-liked-2",
      title: "야간",
      author: "YOON SESAC",
      category: "야경",
      description: "도시의 밤을 깊고 차분하게 잡아내는 시그니처 톤.",
      likeCount: 8200,
      coverURL: nil
    )
  ]
}
