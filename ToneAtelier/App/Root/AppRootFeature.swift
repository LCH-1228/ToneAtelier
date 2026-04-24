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
    case sessionLoaded(SessionSnapshot)
    case task
  }

  @Dependency(\.sessionClient) private var sessionClient

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

        return .run { send in
          let snapshot = await sessionClient.snapshot()
          await send(.sessionLoaded(snapshot))
        }

      case .login(.delegate(.authenticated)):
        state.isAuthenticated = true
        state.isSessionLoading = false
        return .none

      case .logoutCompleted:
        state.isAuthenticated = false
        state.isSessionLoading = false
        state.login = LoginFeature.State()
        state.mainTab = MainTabFeature.State()
        return .none

      case .mainTab(.delegate(.logoutRequested)):
        let sessionClient = sessionClient

        return .run { send in
          await sessionClient.clearTokens()
          await send(.logoutCompleted)
        }

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
