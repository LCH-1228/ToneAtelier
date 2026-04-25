//
//  FeedFeatureTests.swift
//  ToneAtelierTests
//
//  Created by Codex on 4/25/26.
//

import ComposableArchitecture
import XCTest
@testable import ToneAtelier

@MainActor
final class FeedFeatureTests: XCTestCase {
  func testTaskLoadsFeedContent() async {
    let content = FeedScreenContent(
      rankingItems: [
        FeedRankingItem(
          id: "ranking-1",
          rank: 1,
          author: "YOON SESAC",
          title: "청록 새록",
          category: "#인물",
          imageURL: "/photo/ranking.png"
        )
      ],
      filterItems: [
        FeedFilterItem(
          id: "filter-1",
          title: "청연",
          author: "YOON SESAC",
          category: "#인물",
          description: "설명",
          likeCount: 393,
          isLiked: true,
          imageURL: "/photo/filter.png"
        )
      ],
      nextCursor: "next-1"
    )

    let store = TestStore(
      initialState: FeedFeature.State(category: .people)
    ) {
      FeedFeature()
    } withDependencies: {
      $0.feedClient.fetchFeedContent = { _ in content }
    }

    await store.send(.task) {
      $0.isLoading = true
      $0.errorMessage = nil
    }

    await store.receive(\.feedContentResponse.success) {
      $0.isLoading = false
      $0.hasLoaded = true
      $0.rankingItems = content.rankingItems
      $0.filterItems = content.filterItems
      $0.nextCursor = "next-1"
    }
  }

  func testRefreshButtonReloadsFeedContent() async {
    let content = FeedScreenContent(
      rankingItems: [],
      filterItems: [],
      nextCursor: "0"
    )

    let store = TestStore(
      initialState: FeedFeature.State(category: .night)
    ) {
      FeedFeature()
    } withDependencies: {
      $0.feedClient.fetchFeedContent = { _ in content }
    }

    await store.send(.refreshButtonTapped) {
      $0.isLoading = true
      $0.errorMessage = nil
    }

    await store.receive(\.feedContentResponse.success) {
      $0.isLoading = false
      $0.hasLoaded = true
    }
  }

  func testTaskFailureStoresErrorMessage() async {
    let store = TestStore(
      initialState: FeedFeature.State(category: .food)
    ) {
      FeedFeature()
    } withDependencies: {
      $0.feedClient.fetchFeedContent = { _ in
        throw APIError.transport("network down")
      }
    }

    await store.send(.task) {
      $0.isLoading = true
      $0.errorMessage = nil
    }

    await store.receive(\.feedContentResponse.failure) {
      $0.isLoading = false
      $0.hasLoaded = true
      $0.errorMessage = "network down"
    }
  }
}

private extension FeedFeature.Action {
  var feedContentResponse: Result<FeedScreenContent, Error>? {
    guard case let .feedContentResponse(result) = self else { return nil }
    return result
  }
}
