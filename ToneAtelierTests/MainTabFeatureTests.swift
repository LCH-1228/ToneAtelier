//
//  MainTabFeatureTests.swift
//  ToneAtelierTests
//
//  Created by Codex on 4/25/26.
//

import ComposableArchitecture
import XCTest
@testable import ToneAtelier

@MainActor
final class MainTabFeatureTests: XCTestCase {
  func testHomeFeedCategoryDelegateSwitchesToFeedTab() async {
    let store = TestStore(
      initialState: MainTabFeature.State()
    ) {
      MainTabFeature()
    }

    await store.send(.home(.delegate(.feedCategorySelected(.night)))) {
      $0.feed = FeedFeature.State(category: .night)
      $0.selectedTab = 1
    }
  }

  func testFeedBackButtonSwitchesToHomeTab() async {
    var initialState = MainTabFeature.State()
    initialState.selectedTab = 1

    let store = TestStore(
      initialState: initialState
    ) {
      MainTabFeature()
    }

    await store.send(.feedBackButtonTapped) {
      $0.selectedTab = 0
    }
  }
}
