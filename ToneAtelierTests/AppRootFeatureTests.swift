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
  func testTaskAuthenticatesAfterBootstrapRefreshSucceeds() async {
    let store = TestStore(
      initialState: AppRootFeature.State()
    ) {
      AppRootFeature()
    } withDependencies: {
      $0.sessionClient.events = {
        AsyncStream { continuation in
          continuation.finish()
        }
      }
      $0.sessionClient.snapshot = {
        SessionSnapshot(
          configuration: APIConfiguration(
            baseURL: URL(string: "https://example.com")!,
            seSACKey: "sesac-key"
          ),
          accessToken: "access-token",
          refreshToken: "refresh-token"
        )
      }
      $0.authClient.refresh = {
        TokenRefreshResponse(
          accessToken: "new-access-token",
          refreshToken: "new-refresh-token"
        )
      }
      $0.userClient.fetchMyProfile = {
        MyProfileResponse(
          user_id: "user-bootstrap",
          email: nil,
          nick: "tester",
          name: nil,
          introduction: nil,
          profileImage: nil,
          phoneNum: nil,
          hashTags: nil
        )
      }
    }

    await store.send(.task)

    await store.receive(\.bootstrapResponse) {
      $0.isAuthenticated = true
      $0.isSessionLoading = false
      $0.bootstrapFailure = nil
    }
  }

  func testTaskMovesToLoginWhenBootstrapRefreshReturns401() async {
    let clearRecorder = ClearTokensRecorder()

    let store = TestStore(
      initialState: AppRootFeature.State()
    ) {
      AppRootFeature()
    } withDependencies: {
      $0.sessionClient.events = {
        AsyncStream { continuation in
          continuation.finish()
        }
      }
      $0.sessionClient.snapshot = {
        SessionSnapshot(
          configuration: APIConfiguration(
            baseURL: URL(string: "https://example.com")!,
            seSACKey: "sesac-key"
          ),
          accessToken: "access-token",
          refreshToken: "refresh-token"
        )
      }
      $0.sessionClient.clearTokens = {
        await clearRecorder.record()
      }
      $0.authClient.refresh = {
        throw APIError.server(
          statusCode: 401,
          message: "인증할 수 없는 리프레시 토큰입니다.",
          rawBody: nil
        )
      }
    }

    await store.send(.task)

    await store.receive(\.bootstrapResponse) {
      $0.bootstrapFailure = nil
      $0.isAuthenticated = false
      $0.isSessionLoading = false
      $0.login = LoginFeature.State(notice: .reauthenticationRequired)
      $0.mainTab = MainTabFeature.State()
    }

    let clearCount = await clearRecorder.snapshot()
    XCTAssertEqual(clearCount, 1)
  }

  func testTaskShowsRetryableFailureWhenBootstrapRefreshReturns500() async {
    let store = TestStore(
      initialState: AppRootFeature.State()
    ) {
      AppRootFeature()
    } withDependencies: {
      $0.sessionClient.events = {
        AsyncStream { continuation in
          continuation.finish()
        }
      }
      $0.sessionClient.snapshot = {
        SessionSnapshot(
          configuration: APIConfiguration(
            baseURL: URL(string: "https://example.com")!,
            seSACKey: "sesac-key"
          ),
          accessToken: "access-token",
          refreshToken: "refresh-token"
        )
      }
      $0.authClient.refresh = {
        throw APIError.server(
          statusCode: 500,
          message: "ServerError",
          rawBody: nil
        )
      }
    }

    await store.send(.task)

    await store.receive(\.bootstrapResponse) {
      $0.bootstrapFailure = AppRootFeature.BootstrapFailure(
        title: "서버 문제로 세션 확인이 지연되고 있어요.",
        message: "잠시 후 다시 시도해 주세요."
      )
      $0.isAuthenticated = false
      $0.isSessionLoading = false
      $0.mainTab = MainTabFeature.State()
    }
  }

  func testSessionInvalidatedEventResetsToLoginStateWithFeatureNotice() async {
    var initialState = AppRootFeature.State()
    initialState.isAuthenticated = true
    initialState.isSessionLoading = false
    initialState.login.id = "saved"
    initialState.mainTab.selectedTab = .chat

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

private extension AppRootFeature.Action {
  var bootstrapResponse: AppRootFeature.BootstrapResponse? {
    guard case let .bootstrapResponse(response) = self else { return nil }
    return response
  }
}
