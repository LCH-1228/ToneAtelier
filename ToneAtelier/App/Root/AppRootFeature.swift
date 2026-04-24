//
//  AppRootFeature.swift
//  ToneAtelier
//
//  Created by Codex on 4/23/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct AppRootFeature {
  @ObservableState
  struct State: Equatable {
    var isAuthenticated = false
    var isSessionLoading = true
    var login = LoginFeature.State()
    var mainTab = MainTabFeature.State()
  }

  enum Action: Sendable {
    case login(LoginFeature.Action)
    case logoutCompleted
    case mainTab(MainTabFeature.Action)
    case sessionEventReceived(SessionEvent)
    case sessionLoaded(SessionSnapshot)
    case task
  }

  @Dependency(\.sessionClient) private var sessionClient
  @Dependency(\.userClient) private var userClient

  var body: some Reducer<State, Action> {
    Scope(state: \.login, action: \.login) {
      LoginFeature()
    }

    Scope(state: \.mainTab, action: \.mainTab) {
      MainTabFeature()
    }

    Reduce { state, action in
      switch action {
      case .task:
        state.isSessionLoading = true
        let sessionClient = sessionClient

        return .merge(
          .run { send in
            let snapshot = await sessionClient.snapshot()
            await send(.sessionLoaded(snapshot))
          },
          .run { send in
            let events = await sessionClient.events()

            for await event in events {
              await send(.sessionEventReceived(event))
            }
          }
          .cancellable(id: "AppRootFeature.sessionEvents", cancelInFlight: true)
        )

      case .login(.delegate(.authenticated)):
        state.isAuthenticated = true
        state.isSessionLoading = false
        return .none

      case .logoutCompleted:
        state.resetToUnauthenticated()
        return .none

      case .mainTab(.delegate(.logoutRequested)):
        let sessionClient = sessionClient
        let userClient = userClient

        return .run { send in
          do {
            _ = try await userClient.logout()
          } catch {
            // 서버 로그아웃 실패와 무관하게 로컬 세션은 정리한다.
          }

          await sessionClient.clearTokens()
          await send(.logoutCompleted)
        }

      case .sessionEventReceived(.invalidated):
        state.resetToUnauthenticated()
        return .none

      case let .sessionLoaded(snapshot):
        state.isAuthenticated = snapshot.hasAuthenticatedSession
        state.isSessionLoading = false

        if !state.isAuthenticated {
          state.mainTab = MainTabFeature.State()
        }

        return .none

      case .login, .mainTab:
        return .none
      }
    }
  }
}

private extension AppRootFeature.State {
  mutating func resetToUnauthenticated() {
    isAuthenticated = false
    isSessionLoading = false
    login = LoginFeature.State()
    mainTab = MainTabFeature.State()
  }
}

private extension SessionSnapshot {
  var hasAuthenticatedSession: Bool {
    accessToken.isUsableSessionToken && refreshToken.isUsableSessionToken
  }
}

private extension String {
  var isUsableSessionToken: Bool {
    let value = trimmingCharacters(in: .whitespacesAndNewlines)
    return !value.isEmpty && !value.hasPrefix("$(")
  }
}
