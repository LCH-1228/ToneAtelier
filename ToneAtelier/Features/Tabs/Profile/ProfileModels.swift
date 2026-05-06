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
      ProfileStat(value: "10", label: "POST"),
      ProfileStat(value: "132", label: "LIKE")
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
  var authorUserID: String
}

extension FeaturedFilter {
  static let placeholder = FeaturedFilter(
    id: "preview-featured-filter",
    name: "청연",
    meta: "자연광 · 인물 · 12.4K 사용",
    description: "피부 톤을 부드럽게 정돈하는 시그니처 프리셋",
    thumbnailURL: nil,
    authorUserID: ""
  )
}

// TODO: filterClient.likedFilters 응답 항목을 매핑한다.
struct LikedFilter: Identifiable, Equatable, Sendable {
  var id: String
  var title: String
  var author: String
  var authorUserID: String
  var category: String
  var description: String
  var likeCount: Int
  var coverURL: String?
  /// 좋아요 토글 결과를 반영하기 위한 플래그. 좋아한 목록의 초기 적재 시점에는 항상 true이지만,
  /// 토글 후 일시적으로 false 상태가 될 수 있다(목록에서 제거되기 직전 / 부모로 yield 시 사용).
  var isLiked: Bool
}

struct PostListItem: Identifiable, Equatable, Sendable {
  var id: String
  var title: String
  var category: String
  var content: String
  var creatorNick: String
  var creatorUserID: String
  var likeCount: Int
  var imageURL: String?
}

extension LikedFilter {
  /// 좋아요 토글 결과(isLiked)와 likeCount를 함께 반영한다.
  /// 서버가 likeCount를 응답에 포함하지 않는 경우(`nil`)에는 클라이언트가 ±1 추정으로 갱신해
  /// 부모 미리보기 카드가 stale 상태로 남지 않도록 보장한다(Major #11).
  func settingLike(_ newIsLiked: Bool, likeCount newCount: Int?) -> LikedFilter {
    var copy = self
    copy.isLiked = newIsLiked
    if let newCount {
      copy.likeCount = max(0, newCount)
    } else if newIsLiked != isLiked {
      // 서버가 likeCount를 안 줘도 토글 방향에 맞춰 ±1 보정.
      copy.likeCount = max(0, likeCount + (newIsLiked ? 1 : -1))
    }
    return copy
  }

  static let placeholders: [LikedFilter] = [
    LikedFilter(
      id: "preview-liked-1",
      title: "청연",
      author: "YOON SESAC",
      authorUserID: "",
      category: "인물",
      description: "푸르른 여운처럼 마음에 스며드는, 고요하고 깊은 감성의 청록빛 필터.",
      likeCount: 12400,
      coverURL: nil,
      isLiked: true
    ),
    LikedFilter(
      id: "preview-liked-2",
      title: "야간",
      author: "YOON SESAC",
      authorUserID: "",
      category: "야경",
      description: "도시의 밤을 깊고 차분하게 잡아내는 시그니처 톤.",
      likeCount: 8200,
      coverURL: nil,
      isLiked: true
    )
  ]
}
