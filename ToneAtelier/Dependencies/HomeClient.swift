//
//  HomeClient.swift
//  ToneAtelier
//
//  Created by Codex on 4/24/26.
//

import ComposableArchitecture
import Foundation

struct HomeClient {
  var fetchHomeContent: @Sendable () async throws -> HomeScreenContent
}

extension HomeClient: DependencyKey {
  static var liveValue: HomeClient {
    @Dependency(\.bannerClient) var bannerClient
    @Dependency(\.filterClient) var filterClient
    @Dependency(\.userClient) var userClient

    return HomeClient(
      fetchHomeContent: {
        async let bannerResponse = bannerClient.fetchMainBanners()
        async let featuredFilterResponse = filterClient.todayFilter()
        async let hotTrendResponse = filterClient.hotTrend()
        async let todayAuthorResponse = userClient.fetchTodayAuthor()

        let featuredFilter = HomeResponseParser.featuredFilter(
          from: try await featuredFilterResponse
        )
        let banners = HomeResponseParser.banners(
          from: try await bannerResponse.data
        )
        let hotTrends = HomeResponseParser.hotTrends(
          from: try await hotTrendResponse.data
        )
        let featuredAuthor = HomeResponseParser.author(
          from: try await todayAuthorResponse
        )

        return HomeScreenContent(
          featuredFilter: featuredFilter,
          banners: banners,
          hotTrends: hotTrends,
          featuredAuthor: featuredAuthor
        )
      }
    )
  }

  static let testValue = HomeClient(
    fetchHomeContent: {
      throw APIError.transport("HomeClient.fetchHomeContent testValue")
    }
  )
}

extension DependencyValues {
  var homeClient: HomeClient {
    get { self[HomeClient.self] }
    set { self[HomeClient.self] = newValue }
  }
}

private enum HomeResponseParser {
  nonisolated static func featuredFilter(from dto: TodayFilterResponseDTO) -> HomeFeaturedFilter? {
    let title = dto.title.trimmed.nilIfEmpty ?? "오늘의 추천 필터"
    let summary = dto.introduction?.trimmed.nilIfEmpty
      ?? dto.description.trimmed.nilIfEmpty
      ?? "필터 설명이 아직 준비되지 않았어요."
    let imageURL = dto.files.first?.trimmed.nilIfEmpty

    return HomeFeaturedFilter(
      id: dto.filter_id,
      title: title,
      summary: summary,
      imageURL: imageURL
    )
  }

  nonisolated static func banners(from items: [BannerDTO]) -> [HomeBanner] {
    items.enumerated().map { index, item in
      HomeBanner(
        id: "banner-\(index)",
        title: item.name.trimmingCharacters(in: .whitespacesAndNewlines),
        imageURL: item.imageUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : item.imageUrl,
        payload: HomeBannerPayloadType(rawValue: item.payload.type.uppercased()).map {
          HomeBannerPayload(type: $0, value: item.payload.value)
        }
      )
    }
  }

  nonisolated static func hotTrends(from items: [FilterSummaryResponseDTO]) -> [HomeTrend] {
    items.map { item in
      HomeTrend(
        id: item.filter_id,
        title: item.title,
        likeCount: item.like_count,
        imageURL: item.files.first?.trimmed.nilIfEmpty
      )
    }
  }

  nonisolated static func author(from dto: TodayAuthorResponseDTO) -> HomeAuthor? {
    let author = dto.author
    let name = author.nick.trimmed.nilIfEmpty ?? "오늘의 작가"
    let subtitle = author.name?.trimmed.nilIfEmpty ?? name.uppercased()
    let portraitURL = author.profileImage?.trimmed.nilIfEmpty
    let tags = (author.hashTags ?? [])
      .compactMap { $0.trimmed.nilIfEmpty }
      .prefix(3)
      .map { $0.hasPrefix("#") ? $0 : "#\($0)" }

    let quoteSource = author.introduction?.trimmed.nilIfEmpty
      ?? "감도 높은 결과를 만드는 필터 크리에이터"
    let quote = quoteSource.hasPrefix("\"") ? quoteSource : "\"\(quoteSource)\""

    let description = author.description?.trimmed.nilIfEmpty
      ?? author.introduction?.trimmed.nilIfEmpty
      ?? "작가 소개가 아직 준비되지 않았어요."

    let galleryURLs = dto.filters
      .compactMap { $0.files.first?.trimmed.nilIfEmpty }
      .prefix(3)

    return HomeAuthor(
      id: author.user_id,
      name: name,
      subtitle: subtitle,
      portraitURL: portraitURL,
      galleryImageURLs: Array(galleryURLs),
      tags: Array(tags),
      quote: quote,
      description: description
    )
  }
}

private extension String {
  nonisolated var nilIfEmpty: String? { isEmpty ? nil : self }
}
