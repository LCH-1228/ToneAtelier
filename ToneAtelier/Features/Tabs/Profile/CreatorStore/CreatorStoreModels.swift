//
//  CreatorStoreModels.swift
//  ToneAtelier
//
//  Created by Codex on 5/1/26.
//

import Foundation

/// 작가 스토어 화면 헤더 hero 영역 모델.
/// Pencil `YwFLY` (Store Hero) 매핑.
struct CreatorStoreHero: Equatable, Sendable {
  var nickname: String
  var name: String?
  var introduction: String?
  var profileImageURL: String?
  var filterCount: Int

  /// "name · N filters" 형식의 서브 라인. name이 비어 있으면 "N filters"만 노출.
  var subline: String {
    let countText = "\(filterCount) filters"
    if let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmedName.isEmpty {
      return "\(trimmedName) · \(countText)"
    }
    return countText
  }
}

/// 작가 스토어 화면 행 항목 모델.
/// Pencil `q3Ixc` (Store Filter List) 카드 매핑.
struct CreatorStoreItem: Identifiable, Equatable, Sendable {
  var id: String
  var title: String
  var author: String
  var category: String
  var description: String
  var likeCount: Int
  var imageURL: String?
  var price: Int?
  var createdAt: String?
  var isLiked: Bool

  /// HomeDetail에서 좋아요 변동을 받았을 때 카운트만 갈아끼운다.
  /// LikedFilter.settingLikeCount 패턴을 모방.
  func settingLikeCount(_ newCount: Int?) -> CreatorStoreItem {
    guard let newCount, newCount != likeCount else { return self }
    var copy = self
    copy.likeCount = newCount
    return copy
  }
}

/// 작가 스토어 화면 정렬 탭. Pencil `WYtVR` (Store Filter Tabs) 매핑.
enum CreatorStoreFilterTab: String, CaseIterable, Identifiable, Equatable, Sendable {
  case popular
  case recent

  var id: Self { self }

  var title: String {
    switch self {
    case .popular: return "인기순"
    case .recent: return "최신순"
    }
  }
}
