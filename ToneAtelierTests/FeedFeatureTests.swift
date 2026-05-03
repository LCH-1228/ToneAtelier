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

  func testFilterListQueryIncludesSortOption() {
    let query = FilterListQuery(
      next: "",
      limit: 5,
      category: HomeCategory.people.rawValue,
      orderBy: FeedSortOption.purchase.rawValue
    )

    XCTAssertTrue(
      query.queryItems.contains(URLQueryItem(name: "order_by", value: "purchase"))
    )
  }

  func testStateDefaultsToPopularitySortOption() {
    let state = FeedFeature.State(category: .people)

    XCTAssertEqual(state.sortOption, .popularity)
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
          likeCount: 24,
          isLiked: false,
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
      $0.feedClient.fetchFeedContent = { _, sortOption in
        guard sortOption == .popularity else {
          throw APIError.transport("unexpected sort option")
        }
        return content
      }
    }

    await store.send(.task) {
      $0.isLoading = true
      $0.errorMessage = nil
    }

    await store.receive(\.feedContentResponse.success) {
      $0.isLoading = false
      $0.hasLoaded = true
      $0.rankingItems = content.rankingItems
      $0.focusedRankingID = "ranking-1"
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
      $0.feedClient.fetchFeedContent = { _, _ in content }
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
      $0.feedClient.fetchFeedContent = { _, _ in
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
      $0.feedClient.fetchFilterPage = { _, _, _ in
        return FeedFilterPage(
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

  func testSortOptionTappedReloadsOnlyFilterFeed() async {
    let rankingItem = FeedRankingItem(
      id: "ranking-1",
      rank: 1,
      author: "YOON SESAC",
      title: "청연",
      category: "#인물",
      likeCount: 30,
      isLiked: false,
      imageURL: nil
    )
    let oldItem = FeedFilterItem(
      id: "filter-old",
      title: "이전 필터",
      author: "YOON SESAC",
      category: "#인물",
      description: "이전 정렬",
      likeCount: 10,
      isLiked: false,
      imageURL: nil
    )
    let sortedItem = FeedFilterItem(
      id: "filter-sorted",
      title: "구매 필터",
      author: "KIM SESAC",
      category: "#인물",
      description: "구매순",
      likeCount: 100,
      isLiked: true,
      imageURL: nil
    )

    var initialState = FeedFeature.State(category: .people)
    initialState.hasLoaded = true
    initialState.rankingItems = [rankingItem]
    initialState.focusedRankingID = rankingItem.id
    initialState.filterItems = [oldItem]
    initialState.nextCursor = "next-old"

    let store = TestStore(
      initialState: initialState
    ) {
      FeedFeature()
    } withDependencies: {
      $0.feedClient.fetchFilterPage = { _, _, _ in
        return FeedFilterPage(
          items: [sortedItem],
          nextCursor: "next-sorted"
        )
      }
    }

    await store.send(.sortOptionTapped(.purchase)) {
      $0.sortOption = .purchase
      $0.isLoadingFilterFeed = true
      $0.filterFeedErrorMessage = nil
      $0.isLoadingNextPage = false
      $0.nextPageErrorMessage = nil
      $0.nextCursor = "0"
      $0.filterItems = []
    }

    await store.receive(\.filterFeedReloadResponse.success) {
      $0.isLoadingFilterFeed = false
      $0.filterItems = [sortedItem]
      $0.nextCursor = "next-sorted"
    }
  }

  func testSortOptionTappedIgnoresCurrentSortOption() async {
    let store = TestStore(
      initialState: FeedFeature.State(category: .people)
    ) {
      FeedFeature()
    }

    await store.send(.sortOptionTapped(.popularity))
  }

  func testSortOptionTappedIgnoresWhileFeedIsLoading() async {
    var initialState = FeedFeature.State(category: .people)
    initialState.isLoading = true

    let store = TestStore(
      initialState: initialState
    ) {
      FeedFeature()
    }

    await store.send(.sortOptionTapped(.purchase))
  }

  func testFilterLikeButtonTogglesOptimisticallyAndConfirms() async {
    let rankingItem = FeedRankingItem(
      id: "filter-1",
      rank: 1,
      author: "YOON SESAC",
      title: "청연",
      category: "#인물",
      likeCount: 30,
      isLiked: false,
      imageURL: nil
    )
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
    initialState.rankingItems = [rankingItem]
    initialState.filterItems = [firstItem]

    let store = TestStore(
      initialState: initialState
    ) {
      FeedFeature()
    } withDependencies: {
      $0.feedClient.setFilterLike = { _, _ in true }
    }

    await store.send(.filterLikeButtonTapped("filter-1")) {
      $0.pendingLikeSnapshots = [
        "filter-1": FeedLikeSnapshot(
          filterItems: [firstItem],
          rankingItems: [rankingItem]
        )
      ]
      $0.rankingItems = [rankingItem.settingLikeStatus(true)]
      $0.filterItems = [firstItem.settingLikeStatus(true)]
    }

    await store.receive(\.filterLikeSucceeded) {
      $0.pendingLikeSnapshots = [:]
    }
  }

  func testRankingScrollPositionChangedUpdatesFocusedRanking() async {
    let rankingItems = [
      FeedRankingItem(
        id: "ranking-1",
        rank: 1,
        author: "YOON SESAC",
        title: "청연",
        category: "#인물",
        likeCount: 30,
        isLiked: false,
        imageURL: nil
      ),
      FeedRankingItem(
        id: "ranking-2",
        rank: 2,
        author: "KIM SESAC",
        title: "새벽",
        category: "#야경",
        likeCount: 20,
        isLiked: false,
        imageURL: nil
      ),
      FeedRankingItem(
        id: "ranking-3",
        rank: 3,
        author: "PARK SESAC",
        title: "숲길",
        category: "#풍경",
        likeCount: 10,
        isLiked: false,
        imageURL: nil
      ),
    ]

    var initialState = FeedFeature.State(category: .people)
    initialState.rankingItems = rankingItems
    initialState.focusedRankingID = "ranking-2"

    let store = TestStore(
      initialState: initialState
    ) {
      FeedFeature()
    }

    await store.send(.rankingScrollPositionChanged("ranking-3")) {
      $0.focusedRankingID = "ranking-3"
    }
  }

  func testRankingScrollPositionChangedIgnoresInvalidID() async {
    let rankingItems = [
      FeedRankingItem(
        id: "ranking-1",
        rank: 1,
        author: "YOON SESAC",
        title: "청연",
        category: "#인물",
        likeCount: 30,
        isLiked: false,
        imageURL: nil
      ),
      FeedRankingItem(
        id: "ranking-2",
        rank: 2,
        author: "KIM SESAC",
        title: "새벽",
        category: "#야경",
        likeCount: 20,
        isLiked: false,
        imageURL: nil
      ),
    ]

    var initialState = FeedFeature.State(category: .people)
    initialState.rankingItems = rankingItems
    initialState.focusedRankingID = "ranking-1"

    let store = TestStore(
      initialState: initialState
    ) {
      FeedFeature()
    }

    await store.send(.rankingScrollPositionChanged(nil))
    await store.send(.rankingScrollPositionChanged("missing-ranking"))
  }

  func testRankingCardTappedMovesFocusWhenItemIsNotFocused() async {
    let rankingItems = [
      FeedRankingItem(
        id: "ranking-1",
        rank: 1,
        author: "YOON SESAC",
        title: "청연",
        category: "#인물",
        likeCount: 30,
        isLiked: false,
        imageURL: nil
      ),
      FeedRankingItem(
        id: "ranking-2",
        rank: 2,
        author: "KIM SESAC",
        title: "새벽",
        category: "#야경",
        likeCount: 20,
        isLiked: false,
        imageURL: nil
      ),
    ]

    var initialState = FeedFeature.State(category: .people)
    initialState.rankingItems = rankingItems
    initialState.focusedRankingID = "ranking-1"

    let store = TestStore(
      initialState: initialState
    ) {
      FeedFeature()
    }

    await store.send(.rankingCardTapped("ranking-2")) {
      $0.focusedRankingID = "ranking-2"
    }
  }

  func testRankingCardTappedPresentsDetailWhenItemIsFocused() async {
    let rankingItem = FeedRankingItem(
      id: "ranking-1",
      rank: 1,
      author: "YOON SESAC",
      title: "청연",
      category: "#인물",
      likeCount: 30,
      isLiked: true,
      imageURL: nil
    )

    var initialState = FeedFeature.State(category: .people)
    initialState.rankingItems = [rankingItem]
    initialState.focusedRankingID = "ranking-1"

    let store = TestStore(
      initialState: initialState
    ) {
      FeedFeature()
    }

    await store.send(.rankingCardTapped("ranking-1")) {
      $0.detail = HomeDetailFeature.State(
        id: rankingItem.id,
        title: rankingItem.title,
        summary: nil,
        likeCount: rankingItem.likeCount
      )
    }
  }

  func testFeedContentResponsePreservesFocusedRankingWhenItStillExists() async {
    let rankingItems = [
      FeedRankingItem(
        id: "ranking-1",
        rank: 1,
        author: "YOON SESAC",
        title: "청연",
        category: "#인물",
        likeCount: 30,
        isLiked: false,
        imageURL: nil
      ),
      FeedRankingItem(
        id: "ranking-2",
        rank: 2,
        author: "KIM SESAC",
        title: "새벽",
        category: "#야경",
        likeCount: 20,
        isLiked: false,
        imageURL: nil
      ),
    ]

    var initialState = FeedFeature.State(category: .people)
    initialState.focusedRankingID = "ranking-2"

    let store = TestStore(
      initialState: initialState
    ) {
      FeedFeature()
    }

    await store.send(
      .feedContentResponse(.success(FeedScreenContent(
        rankingItems: rankingItems,
        filterItems: [],
        nextCursor: "0"
      )))
    ) {
      $0.hasLoaded = true
      $0.rankingItems = rankingItems
      $0.focusedRankingID = "ranking-2"
      $0.nextCursor = "0"
    }
  }

  func testFeedContentResponseFallsBackFocusedRankingWhenCurrentItemDisappears() async {
    let rankingItems = [
      FeedRankingItem(
        id: "ranking-1",
        rank: 1,
        author: "YOON SESAC",
        title: "청연",
        category: "#인물",
        likeCount: 30,
        isLiked: false,
        imageURL: nil
      ),
      FeedRankingItem(
        id: "ranking-2",
        rank: 2,
        author: "KIM SESAC",
        title: "새벽",
        category: "#야경",
        likeCount: 20,
        isLiked: false,
        imageURL: nil
      ),
    ]

    var initialState = FeedFeature.State(category: .people)
    initialState.focusedRankingID = "missing-ranking"

    let store = TestStore(
      initialState: initialState
    ) {
      FeedFeature()
    }

    await store.send(
      .feedContentResponse(.success(FeedScreenContent(
        rankingItems: rankingItems,
        filterItems: [],
        nextCursor: "0"
      )))
    ) {
      $0.hasLoaded = true
      $0.rankingItems = rankingItems
      $0.focusedRankingID = "ranking-1"
      $0.nextCursor = "0"
    }
  }

  func testFilterCardTappedPresentsDetailFromFilterItem() async {
    let item = FeedFilterItem(
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
    initialState.filterItems = [item]

    let store = TestStore(
      initialState: initialState
    ) {
      FeedFeature()
    }

    await store.send(.filterCardTapped("filter-1")) {
      $0.detail = HomeDetailFeature.State(
        id: item.id,
        title: item.title,
        summary: item.description,
        likeCount: item.likeCount
      )
    }
  }

  func testRankingCardTappedPresentsDetailFromRankingItem() async {
    let rankingItem = FeedRankingItem(
      id: "filter-1",
      rank: 1,
      author: "YOON SESAC",
      title: "청연",
      category: "#인물",
      likeCount: 30,
      isLiked: true,
      imageURL: nil
    )

    var initialState = FeedFeature.State(category: .people)
    initialState.rankingItems = [rankingItem]

    let store = TestStore(
      initialState: initialState
    ) {
      FeedFeature()
    }

    await store.send(.filterCardTapped("filter-1")) {
      $0.detail = HomeDetailFeature.State(
        id: rankingItem.id,
        title: rankingItem.title,
        summary: nil,
        likeCount: rankingItem.likeCount
      )
    }
  }

  func testFilterLikeFailureRollsBackOptimisticUpdate() async {
    let rankingItem = FeedRankingItem(
      id: "filter-1",
      rank: 1,
      author: "YOON SESAC",
      title: "청연",
      category: "#인물",
      likeCount: 30,
      isLiked: false,
      imageURL: nil
    )
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
    initialState.rankingItems = [rankingItem]
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
      $0.pendingLikeSnapshots = [
        "filter-1": FeedLikeSnapshot(
          filterItems: [firstItem],
          rankingItems: [rankingItem]
        )
      ]
      $0.rankingItems = [rankingItem.settingLikeStatus(true)]
      $0.filterItems = [firstItem.settingLikeStatus(true)]
    }

    await store.receive(\.filterLikeFailed, "filter-1") {
      $0.pendingLikeSnapshots = [:]
      $0.rankingItems = [rankingItem]
      $0.filterItems = [firstItem]
    }
  }

  func testFilterLikeSuccessUsesConfirmedServerStatus() async {
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
      $0.feedClient.setFilterLike = { _, _ in false }
    }

    await store.send(.filterLikeButtonTapped("filter-1")) {
      $0.pendingLikeSnapshots = [
        "filter-1": FeedLikeSnapshot(
          filterItems: [firstItem],
          rankingItems: []
        )
      ]
      $0.filterItems = [firstItem.settingLikeStatus(true)]
    }

    await store.receive(\.filterLikeSucceeded) {
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
      $0.feedClient.fetchFilterPage = { _, _, _ in
        return FeedFilterPage(
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

  var filterFeedReloadResponse: Result<FeedFilterPage, Error>? {
    guard case let .filterFeedReloadResponse(result) = self else { return nil }
    return result
  }

  var loadNextPageResponse: Result<FeedFilterPage, Error>? {
    guard case let .loadNextPageResponse(result) = self else { return nil }
    return result
  }

  var filterLikeSucceeded: String? {
    guard case let .filterLikeSucceeded(id, status) = self else { return nil }
    return "\(id):\(status)"
  }

  var filterLikeFailed: FeedFilterItem.ID? {
    guard case let .filterLikeFailed(id) = self else { return nil }
    return id
  }
}
