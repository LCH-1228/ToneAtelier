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
        HomeBanner(id: "banner-1", imageURL: "https://example.com/banner.png")
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
      $0.hotTrends = content.hotTrends
      $0.focusedTrendID = "trend-2"
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
}

private extension HomeFeature.Action {
  var homeContentResponse: Result<HomeScreenContent, Error>? {
    guard case let .homeContentResponse(result) = self else { return nil }
    return result
  }
}
