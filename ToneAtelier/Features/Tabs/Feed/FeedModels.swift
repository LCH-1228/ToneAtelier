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
