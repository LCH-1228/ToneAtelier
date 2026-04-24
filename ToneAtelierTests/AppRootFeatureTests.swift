//
//  AppRootFeatureTests.swift
//  ToneAtelierTests
//
//  Created by Codex on 4/24/26.
//

import ComposableArchitecture
import XCTest
@testable import ToneAtelier

@MainActor
final class AppRootFeatureTests: XCTestCase {

  func testSessionInvalidatedEventResetsToLoginStateWithFeatureNotice() async {
    var initialState = AppRootFeature.State()
    initialState.isAuthenticated = true
    initialState.isSessionLoading = false
    initialState.login.id = "saved"
    initialState.mainTab.selectedTab = 3

    let store = TestStore(
      initialState: initialState
    ) {
      AppRootFeature()
    }

    await store.send(
      .sessionEventReceived(
        .invalidated(.expired(statusCode: 419))
      )
    ) {
      $0.isAuthenticated = false
      $0.isSessionLoading = false
      $0.login = LoginFeature.State(notice: .sessionExpired)
      $0.mainTab = MainTabFeature.State()
    }
  }

  func testLogoutRequestedMovesToLoginEvenWhenServerLogoutFails() async {
    let clearRecorder = ClearTokensRecorder()
    var initialState = AppRootFeature.State()
    initialState.isAuthenticated = true
    initialState.isSessionLoading = false

    let store = TestStore(
      initialState: initialState
    ) {
      AppRootFeature()
    } withDependencies: {
      $0.sessionClient.clearTokens = {
        await clearRecorder.record()
      }
      $0.userClient.logout = {
        throw APIError.transport("network unavailable")
      }
    }

    await store.send(.mainTab(.delegate(.logoutRequested)))
    await store.receive(\.logoutCompleted) {
      $0.isAuthenticated = false
      $0.isSessionLoading = false
      $0.login = LoginFeature.State()
      $0.mainTab = MainTabFeature.State()
    }

    let clearCount = await clearRecorder.snapshot()
    XCTAssertEqual(clearCount, 1)
  }
}

private actor ClearTokensRecorder {
  private var count = 0

  func record() {
    count += 1
  }

  func snapshot() -> Int {
    count
  }
}
