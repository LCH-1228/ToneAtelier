//
//  FeedModels.swift
//  ToneAtelier
//
//  Created by Codex on 4/25/26.
//

import Foundation

struct FeedScreenContent: Equatable, Sendable {
  var rankingItems: [FeedRankingItem]
  var filterItems: [FeedFilterItem]
  var nextCursor: String
}

struct FeedFilterPage: Equatable, Sendable {
  var items: [FeedFilterItem]
  var nextCursor: String
}

struct FeedMasonryColumnLayout: Equatable, Sendable {
  var leftIndexes: [Int]
  var rightIndexes: [Int]

  nonisolated static func make(
    itemCount: Int,
    heightForIndex: (Int) -> Double
  ) -> Self {
    var leftIndexes: [Int] = []
    var rightIndexes: [Int] = []
    var leftHeight = 0.0
    var rightHeight = 0.0

    for index in 0..<itemCount {
      let itemHeight = heightForIndex(index)

      if leftHeight <= rightHeight {
        leftIndexes.append(index)
        leftHeight += itemHeight
      } else {
        rightIndexes.append(index)
        rightHeight += itemHeight
      }
    }

    return FeedMasonryColumnLayout(
      leftIndexes: leftIndexes,
      rightIndexes: rightIndexes
    )
  }
}

enum FeedSortOption: String, CaseIterable, Equatable, Sendable {
  case popularity
  case purchase
  case latest

  static let displayOptions: [Self] = [.popularity, .purchase, .latest]

  var title: String {
    switch self {
    case .popularity: return "인기순"
    case .purchase: return "구매순"
    case .latest: return "최신순"
    }
  }
}

struct FeedRankingItem: Equatable, Identifiable, Sendable {
  let id: String
  let rank: Int
  let author: String
  let title: String
  let category: String
  let likeCount: Int
  let isLiked: Bool
  let imageURL: String?

  nonisolated func settingLikeStatus(_ newStatus: Bool) -> Self {
    settingLikeStatus(newStatus, likeCount: nil)
  }

  nonisolated func settingLikeStatus(_ newStatus: Bool, likeCount newLikeCount: Int?) -> Self {
    if isLiked == newStatus, newLikeCount == nil {
      return self
    }

    return FeedRankingItem(
      id: id,
      rank: rank,
      author: author,
      title: title,
      category: category,
      likeCount: max(0, newLikeCount ?? likeCount + (newStatus ? 1 : -1)),
      isLiked: newStatus,
      imageURL: imageURL
    )
  }
}

struct FeedFilterItem: Equatable, Identifiable, Sendable {
  let id: String
  let title: String
  let author: String
  let category: String
  let description: String
  let likeCount: Int
  let isLiked: Bool
  let imageURL: String?

  nonisolated func settingLikeStatus(_ newStatus: Bool) -> Self {
    settingLikeStatus(newStatus, likeCount: nil)
  }

  nonisolated func settingLikeStatus(_ newStatus: Bool, likeCount newLikeCount: Int?) -> Self {
    if isLiked == newStatus, newLikeCount == nil {
      return self
    }

    return FeedFilterItem(
      id: id,
      title: title,
      author: author,
      category: category,
      description: description,
      likeCount: max(0, newLikeCount ?? likeCount + (newStatus ? 1 : -1)),
      isLiked: newStatus,
      imageURL: imageURL
    )
  }
}

struct FeedLikeSnapshot: Equatable, Sendable {
  let filterItems: [FeedFilterItem]
  let rankingItems: [FeedRankingItem]
}
