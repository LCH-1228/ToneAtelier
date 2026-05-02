//
//  FeedClient.swift
//  ToneAtelier
//
//  Created by Codex on 4/25/26.
//

import ComposableArchitecture
import Foundation

struct FeedClient {
  var fetchFeedContent: @Sendable (_ category: HomeCategory?, _ sortOption: FeedSortOption) async throws -> FeedScreenContent
  var fetchFilterPage: @Sendable (_ category: HomeCategory?, _ sortOption: FeedSortOption, _ nextCursor: String) async throws -> FeedFilterPage
  var setFilterLike: @Sendable (_ filterID: FeedFilterItem.ID, _ likeStatus: Bool) async throws -> Bool
}

extension FeedClient: DependencyKey {
  static var liveValue: FeedClient {
    @Dependency(\.filterClient) var filterClient

    let fetchFilterPage: @Sendable (HomeCategory?, FeedSortOption, String) async throws -> FeedFilterPage = { category, sortOption, nextCursor in
      let response = try await filterClient.list(
        FilterListQuery(
          next: nextCursor,
          limit: 5,
          category: category?.rawValue,
          orderBy: sortOption.rawValue
        )
      )

      return FeedFilterPage(
        items: FeedResponseParser.filterItems(
          from: response.data,
          fallbackCategory: category
        ),
        nextCursor: response.nextCursor ?? "0"
      )
    }

    return FeedClient(
      fetchFeedContent: { category, sortOption in
        async let rankingResponse = filterClient.hotTrend()
        async let filterPage = fetchFilterPage(category, sortOption, "")

        let (rankingResponseValue, filterPageValue) = try await (rankingResponse, filterPage)

        let rankingItems = FeedResponseParser.rankingItems(
          from: rankingResponseValue.data,
          fallbackCategory: category
        )

        return FeedScreenContent(
          rankingItems: rankingItems,
          filterItems: filterPageValue.items,
          nextCursor: filterPageValue.nextCursor
        )
      },
      fetchFilterPage: fetchFilterPage,
      setFilterLike: { filterID, likeStatus in
        try await filterClient.setLike(filterID, likeStatus).likeStatus
      }
    )
  }

  static let testValue = FeedClient(
    fetchFeedContent: { _, _ in
      throw APIError.transport("FeedClient.fetchFeedContent testValue")
    },
    fetchFilterPage: { _, _, _ in
      throw APIError.transport("FeedClient.fetchFilterPage testValue")
    },
    setFilterLike: { _, _ in
      throw APIError.transport("FeedClient.setFilterLike testValue")
    }
  )
}

extension DependencyValues {
  var feedClient: FeedClient {
    get { self[FeedClient.self] }
    set { self[FeedClient.self] = newValue }
  }
}

private enum FeedResponseParser {
  /// hot-trend는 FilterSummaryResponseDTO 배열로 반환된다.
  nonisolated static func rankingItems(
    from items: [FilterSummaryResponseDTO],
    fallbackCategory: HomeCategory?
  ) -> [FeedRankingItem] {
    items.enumerated().map { index, item in
      FeedRankingItem(
        id: item.filterID,
        rank: index + 1,
        author: item.creator.nick.uppercased(),
        title: item.title,
        category: displayCategory(item.category ?? "", fallback: fallbackCategory),
        likeCount: item.likeCount,
        isLiked: item.isLiked,
        imageURL: item.files.first
      )
    }
  }

  /// /v1/filters GET 응답은 FilterSummaryResponseDTO 배열로 온다.
  nonisolated static func filterItems(
    from items: [FilterSummaryResponseDTO],
    fallbackCategory: HomeCategory?
  ) -> [FeedFilterItem] {
    items.map { item in
      FeedFilterItem(
        id: item.filterID,
        title: item.title,
        author: item.creator.nick.uppercased(),
        category: displayCategory(item.category ?? "", fallback: fallbackCategory),
        description: item.description.trimmed.nilIfEmpty ?? "필터 설명이 아직 준비되지 않았어요.",
        likeCount: item.likeCount,
        isLiked: item.isLiked,
        imageURL: item.files.first
      )
    }
  }

  nonisolated private static func displayCategory(_ raw: String, fallback: HomeCategory?) -> String {
    let normalized = raw.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    if let category = HomeCategory(rawValue: normalized) {
      return "#\(category.title)"
    }
    if let category = HomeCategory.allCases.first(where: { $0.title == normalized }) {
      return "#\(category.title)"
    }
    return normalized.isEmpty ? (fallback.map { "#\($0.title)" } ?? "#필터") : "#\(normalized)"
  }
}

private extension String {
  nonisolated var nilIfEmpty: String? { isEmpty ? nil : self }
}
