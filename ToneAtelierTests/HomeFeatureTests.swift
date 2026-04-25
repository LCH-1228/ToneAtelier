//
//  HomeFeatureTests.swift
//  ToneAtelierTests
//
//  Created by Codex on 4/24/26.
//

import ComposableArchitecture
import XCTest
@testable import ToneAtelier

@MainActor
final class HomeFeatureTests: XCTestCase {
  func testTaskLoadsHomeContent() async {
    let content = HomeScreenContent(
      featuredFilter: HomeFeaturedFilter(
        id: "filter-1",
        title: "청록 새록",
        summary: "설명",
        imageURL: "https://example.com/filter.png"
      ),
      banners: [
        HomeBanner(
          id: "banner-1",
          title: "배너 1",
          imageURL: "https://example.com/banner.png",
          payload: nil
        )
      ],
      hotTrends: [
        HomeTrend(id: "trend-1", title: "새벽", likeCount: 10, imageURL: nil),
        HomeTrend(id: "trend-2", title: "소낙새", likeCount: 121, imageURL: nil)
      ],
      featuredAuthor: HomeAuthor(
        id: "author-1",
        name: "윤새싹",
        subtitle: "SESAC YOON",
        portraitURL: nil,
        galleryImageURLs: [],
        tags: ["#자연"],
        quote: "\"작가 소개\"",
        description: "설명"
      )
    )

    let store = TestStore(
      initialState: HomeFeature.State()
    ) {
      HomeFeature()
    } withDependencies: {
      $0.homeClient.fetchHomeContent = {
        content
      }
    }

    await store.send(.task) {
      $0.isLoading = true
      $0.errorMessage = nil
    }

    await store.receive(\.homeContentResponse) {
      $0.isLoading = false
      $0.hasLoaded = true
      $0.featuredFilter = content.featuredFilter
      $0.banners = content.banners
      $0.currentBannerIndex = 0
      $0.hotTrends = content.hotTrends
      $0.focusedTrendID = "trend-1"
      $0.featuredAuthor = content.featuredAuthor
    }
  }

  func testTaskFailureStoresErrorMessage() async {
    let store = TestStore(
      initialState: HomeFeature.State()
    ) {
      HomeFeature()
    } withDependencies: {
      $0.homeClient.fetchHomeContent = {
        throw APIError.transport("network down")
      }
    }

    await store.send(.task) {
      $0.isLoading = true
      $0.errorMessage = nil
    }

    await store.receive(\.homeContentResponse) {
      $0.isLoading = false
      $0.hasLoaded = true
      $0.errorMessage = "network down"
    }
  }

  func testBannerIndexChangedUpdatesCurrentBannerIndex() async {
    var initialState = HomeFeature.State()
    initialState.banners = [
      HomeBanner(id: "banner-1", title: "배너 1", imageURL: nil, payload: nil),
      HomeBanner(id: "banner-2", title: "배너 2", imageURL: nil, payload: nil),
      HomeBanner(id: "banner-3", title: "배너 3", imageURL: nil, payload: nil),
    ]

    let store = TestStore(
      initialState: initialState
    ) {
      HomeFeature()
    }

    await store.send(.bannerIndexChanged(2)) {
      $0.currentBannerIndex = 2
    }
  }

  func testBannerTappedPreparesWebViewDestination() async {
    var initialState = HomeFeature.State()
    initialState.banners = [
      HomeBanner(
        id: "banner-1",
        title: "메인뷰 배너",
        imageURL: nil,
        payload: HomeBannerPayload(type: .webView, value: "/event-application")
      )
    ]

    let webViewRequest = WebViewRequest(
      url: URL(string: "http://example.com/event-application")!,
      headers: ["SeSACKey": "test-key"]
    )

    let store = TestStore(
      initialState: initialState
    ) {
      HomeFeature()
    } withDependencies: {
      $0.commonClient.makeWebViewRequest = { _ in
        webViewRequest
      }
      $0.sessionClient.snapshot = {
        SessionSnapshot(
          configuration: .default,
          accessToken: "access-token",
          refreshToken: "refresh-token"
        )
      }
    }

    await store.send(.bannerTapped("banner-1"))

    await store.receive(\.bannerWebViewPrepared.success) {
      $0.bannerWebView = HomeBannerWebFeature.State(
        title: "출석체크 이벤트",
        webViewRequest: webViewRequest,
        accessToken: "access-token"
      )
    }
  }

  func testCategoryTappedPresentsFeedDestination() async {
    let store = TestStore(
      initialState: HomeFeature.State()
    ) {
      HomeFeature()
    }

    await store.send(.categoryTapped(.food)) {
      $0.feed = FeedFeature.State(category: .food)
    }
  }

  func testHotTrendTappedPresentsDetailDestination() async {
    var initialState = HomeFeature.State()
    initialState.hotTrends = [
      HomeTrend(id: "trend-1", title: "트렌드 1", likeCount: 30, imageURL: nil),
      HomeTrend(id: "trend-2", title: "트렌드 2", likeCount: 121, imageURL: nil),
    ]

    let store = TestStore(
      initialState: initialState
    ) {
      HomeFeature()
    }

    await store.send(.hotTrendTapped("trend-2")) {
      $0.detail = HomeDetailFeature.State(
        trend: HomeTrend(id: "trend-2", title: "트렌드 2", likeCount: 121, imageURL: nil)
      )
    }
  }

  func testHotTrendScrollPositionChangedUpdatesFocusedID() async {
    var initialState = HomeFeature.State()
    initialState.hotTrends = [
      HomeTrend(id: "trend-1", title: "트렌드 1", likeCount: 30, imageURL: nil),
      HomeTrend(id: "trend-2", title: "트렌드 2", likeCount: 121, imageURL: nil),
    ]
    initialState.focusedTrendID = "trend-1"

    let store = TestStore(
      initialState: initialState
    ) {
      HomeFeature()
    }

    await store.send(.hotTrendScrollPositionChanged("trend-2")) {
      $0.focusedTrendID = "trend-2"
    }
  }

  func testTryFeaturedFilterButtonTappedPresentsDetailDestination() async {
    var initialState = HomeFeature.State()
    let featuredFilter = HomeFeaturedFilter(
      id: "filter-1",
      title: "오늘의 필터",
      summary: "오늘의 필터 설명",
      imageURL: nil
    )
    initialState.featuredFilter = featuredFilter

    let store = TestStore(
      initialState: initialState
    ) {
      HomeFeature()
    }

    await store.send(.tryFeaturedFilterButtonTapped) {
      $0.detail = HomeDetailFeature.State(
        featuredFilter: featuredFilter
      )
    }
  }
}

private extension HomeFeature.Action {
  var homeContentResponse: Result<HomeScreenContent, Error>? {
    guard case let .homeContentResponse(result) = self else { return nil }
    return result
  }

  var bannerWebViewPrepared: Result<HomeBannerWebFeature.State, Error>? {
    guard case let .bannerWebViewPrepared(result) = self else { return nil }
    return result
  }
}
