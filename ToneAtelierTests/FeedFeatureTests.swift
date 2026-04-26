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
  func testMasonryLayoutHandlesEmptyAndSingleItem() {
    XCTAssertEqual(
      FeedMasonryColumnLayout.make(itemCount: 0) { _ in 100 },
      FeedMasonryColumnLayout(leftIndexes: [], rightIndexes: [])
    )
    XCTAssertEqual(
      FeedMasonryColumnLayout.make(itemCount: 1) { _ in 100 },
      FeedMasonryColumnLayout(leftIndexes: [0], rightIndexes: [])
    )
  }

  func testMasonryLayoutPlacesNextItemInShorterColumn() {
    let heights = [300.0, 100.0, 100.0, 50.0]

    let layout = FeedMasonryColumnLayout.make(itemCount: heights.count) { index in
      heights[index]
    }

    XCTAssertEqual(layout.leftIndexes, [0])
    XCTAssertEqual(layout.rightIndexes, [1, 2, 3])
  }

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

  func testFilterItemAppearedLoadsNextPage() async {
    let firstItem = FeedFilterItem(
      id: "filter-1",
      title: "청연",
      author: "YOON SESAC",
      category: "#인물",
      description: "첫 페이지",
      likeCount: 10,
      isLiked: false,
      imageURL: nil
    )
    let nextItem = FeedFilterItem(
      id: "filter-2",
      title: "새벽",
      author: "KIM SESAC",
      category: "#야경",
      description: "다음 페이지",
      likeCount: 20,
      isLiked: true,
      imageURL: nil
    )

    var initialState = FeedFeature.State(category: .people)
    initialState.hasLoaded = true
    initialState.filterItems = [firstItem]
    initialState.nextCursor = "next-1"

    let store = TestStore(
      initialState: initialState
    ) {
      FeedFeature()
    } withDependencies: {
      $0.feedClient.fetchFilterPage = { _, _ in
        FeedFilterPage(
          items: [nextItem],
          nextCursor: "0"
        )
      }
    }

    await store.send(.filterItemAppeared("filter-1")) {
      $0.isLoadingNextPage = true
      $0.nextPageErrorMessage = nil
    }

    await store.receive(\.loadNextPageResponse.success) {
      $0.isLoadingNextPage = false
      $0.filterItems = [firstItem, nextItem]
      $0.nextCursor = "0"
    }
  }

  func testFilterItemAppearedIgnoresLastPage() async {
    let firstItem = FeedFilterItem(
      id: "filter-1",
      title: "청연",
      author: "YOON SESAC",
      category: "#인물",
      description: "첫 페이지",
      likeCount: 10,
      isLiked: false,
      imageURL: nil
    )

    var initialState = FeedFeature.State(category: .people)
    initialState.hasLoaded = true
    initialState.filterItems = [firstItem]
    initialState.nextCursor = "0"

    let store = TestStore(
      initialState: initialState
    ) {
      FeedFeature()
    }

    await store.send(.filterItemAppeared("filter-1"))
  }

  func testFilterLikeButtonTogglesOptimisticallyAndConfirms() async {
    let firstItem = FeedFilterItem(
      id: "filter-1",
      title: "청연",
      author: "YOON SESAC",
      category: "#인물",
      description: "첫 페이지",
      likeCount: 10,
      isLiked: false,
      imageURL: nil
    )

    var initialState = FeedFeature.State(category: .people)
    initialState.hasLoaded = true
    initialState.filterItems = [firstItem]

    let store = TestStore(
      initialState: initialState
    ) {
      FeedFeature()
    } withDependencies: {
      $0.feedClient.setFilterLike = { _, _ in }
    }

    await store.send(.filterLikeButtonTapped("filter-1")) {
      $0.pendingLikeSnapshots = ["filter-1": firstItem]
      $0.filterItems = [firstItem.settingLikeStatus(true)]
    }

    await store.receive(\.filterLikeSucceeded, "filter-1") {
      $0.pendingLikeSnapshots = [:]
    }
  }

  func testFilterLikeFailureRollsBackOptimisticUpdate() async {
    let firstItem = FeedFilterItem(
      id: "filter-1",
      title: "청연",
      author: "YOON SESAC",
      category: "#인물",
      description: "첫 페이지",
      likeCount: 10,
      isLiked: false,
      imageURL: nil
    )

    var initialState = FeedFeature.State(category: .people)
    initialState.hasLoaded = true
    initialState.filterItems = [firstItem]

    let store = TestStore(
      initialState: initialState
    ) {
      FeedFeature()
    } withDependencies: {
      $0.feedClient.setFilterLike = { _, _ in
        throw APIError.transport("network down")
      }
    }

    await store.send(.filterLikeButtonTapped("filter-1")) {
      $0.pendingLikeSnapshots = ["filter-1": firstItem]
      $0.filterItems = [firstItem.settingLikeStatus(true)]
    }

    await store.receive(\.filterLikeFailed, "filter-1") {
      $0.pendingLikeSnapshots = [:]
      $0.filterItems = [firstItem]
    }
  }

  func testNextPageWithDuplicateItemsAndSameCursorStopsPagination() async {
    let firstItem = FeedFilterItem(
      id: "filter-1",
      title: "청연",
      author: "YOON SESAC",
      category: "#인물",
      description: "첫 페이지",
      likeCount: 10,
      isLiked: false,
      imageURL: nil
    )

    var initialState = FeedFeature.State(category: .people)
    initialState.hasLoaded = true
    initialState.filterItems = [firstItem]
    initialState.nextCursor = "next-1"

    let store = TestStore(
      initialState: initialState
    ) {
      FeedFeature()
    } withDependencies: {
      $0.feedClient.fetchFilterPage = { _, _ in
        FeedFilterPage(
          items: [firstItem],
          nextCursor: "next-1"
        )
      }
    }

    await store.send(.filterItemAppeared("filter-1")) {
      $0.isLoadingNextPage = true
      $0.nextPageErrorMessage = nil
    }

    await store.receive(\.loadNextPageResponse.success) {
      $0.isLoadingNextPage = false
      $0.nextCursor = "0"
    }
  }
}

private extension FeedFeature.Action {
  var feedContentResponse: Result<FeedScreenContent, Error>? {
    guard case let .feedContentResponse(result) = self else { return nil }
    return result
  }

  var loadNextPageResponse: Result<FeedFilterPage, Error>? {
    guard case let .loadNextPageResponse(result) = self else { return nil }
    return result
  }

  var filterLikeSucceeded: FeedFilterItem.ID? {
    guard case let .filterLikeSucceeded(id) = self else { return nil }
    return id
  }

  var filterLikeFailed: FeedFilterItem.ID? {
    guard case let .filterLikeFailed(id) = self else { return nil }
    return id
  }
}
