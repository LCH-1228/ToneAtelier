//
//  HomeModels.swift
//  ToneAtelier
//
//  Created by Codex on 4/24/26.
//

import Foundation

struct HomeScreenContent: Equatable, Sendable {
  var featuredFilter: HomeFeaturedFilter?
  var banners: [HomeBanner]
  var hotTrends: [HomeTrend]
  var featuredAuthor: HomeAuthor?
}

struct HomeFeaturedFilter: Equatable, Identifiable, Sendable {
  let id: String
  let title: String
  let summary: String
  let imageURL: String?
}

struct HomeBanner: Equatable, Identifiable, Sendable {
  let id: String
  let imageURL: String?
}

struct HomeTrend: Equatable, Identifiable, Sendable {
  let id: String
  let title: String
  let likeCount: Int
  let imageURL: String?
}

struct HomeAuthor: Equatable, Identifiable, Sendable {
  let id: String
  let name: String
  let subtitle: String
  let portraitURL: String?
  let galleryImageURLs: [String]
  let tags: [String]
  let quote: String
  let description: String
}

enum HomeCategory: String, CaseIterable, Equatable, Identifiable, Sendable {
  case food
  case people
  case landscape
  case night
  case star

  var id: String { rawValue }

  var title: String {
    switch self {
    case .food: return "푸드"
    case .people: return "인물"
    case .landscape: return "풍경"
    case .night: return "야경"
    case .star: return "별"
    }
  }

  var assetName: String {
    switch self {
    case .food: return AppAsset.HomeCategory.food
    case .people: return AppAsset.HomeCategory.people
    case .landscape: return AppAsset.HomeCategory.landscape
    case .night: return AppAsset.HomeCategory.night
    case .star: return AppAsset.HomeCategory.star
    }
  }
}
