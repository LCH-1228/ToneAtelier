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

enum HomeBannerPayloadType: String, Equatable, Sendable {
  case webView = "WEBVIEW"
}

struct HomeBannerPayload: Equatable, Sendable {
  let type: HomeBannerPayloadType
  let value: String
}

struct HomeBanner: Equatable, Identifiable, Sendable {
  let id: String
  let title: String
  let imageURL: String?
  let payload: HomeBannerPayload?

  nonisolated
  var displayTitle: String {
    if let payload,
       payload.type == .webView,
       payload.value.trimmed == "/event-application" {
      return "출석체크 이벤트"
    }

    let normalizedTitle = title.trimmed
    if normalizedTitle.isEmpty {
      return "배너 이벤트"
    }

    if normalizedTitle.lowercased().hasPrefix("banner") {
      return "배너 이벤트"
    }

    return normalizedTitle
  }
}

struct HomeTrend: Equatable, Identifiable, Sendable {
  let id: String
  let title: String
  let likeCount: Int
  let imageURL: String?

  nonisolated func settingLikeCount(_ newLikeCount: Int?) -> Self {
    HomeTrend(
      id: id,
      title: title,
      likeCount: max(0, newLikeCount ?? likeCount),
      imageURL: imageURL
    )
  }
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

  nonisolated var id: String { rawValue }

  nonisolated var title: String {
    switch self {
    case .food: return "푸드"
    case .people: return "인물"
    case .landscape: return "풍경"
    case .night: return "야경"
    case .star: return "별"
    }
  }

  nonisolated var assetName: String {
    switch self {
    case .food: return AppAsset.HomeCategory.food
    case .people: return AppAsset.HomeCategory.people
    case .landscape: return AppAsset.HomeCategory.landscape
    case .night: return AppAsset.HomeCategory.night
    case .star: return AppAsset.HomeCategory.star
    }
  }
}
