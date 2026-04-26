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

struct FeedRankingItem: Equatable, Identifiable, Sendable {
  let id: String
  let rank: Int
  let author: String
  let title: String
  let category: String
  let imageURL: String?
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
}
