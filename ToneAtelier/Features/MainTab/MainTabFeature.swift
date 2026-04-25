//
//  MainTabFeature.swift
//  ToneAtelier
//
//  Created by Codex on 4/23/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct MainTabFeature {
  @ObservableState
  struct State: Equatable {
    var home = HomeFeature.State()
    var feed = FeedFeature.State(category: nil)
    var selectedTab = 0
  }

  enum Action: BindableAction, Sendable {
    case binding(BindingAction<State>)
    case delegate(Delegate)
    case feed(FeedFeature.Action)
    case feedBackButtonTapped
    case home(HomeFeature.Action)
    case logoutButtonTapped

    enum Delegate: Equatable, Sendable {
      case logoutRequested
    }
  }

  var body: some Reducer<State, Action> {
    Scope(state: \.home, action: \.home) {
      HomeFeature()
    }

    Scope(state: \.feed, action: \.feed) {
      FeedFeature()
    }

    BindingReducer()

    Reduce { state, action in
      switch action {
      case .binding:
        return .none

      case .feed:
        return .none

      case .feedBackButtonTapped:
        state.selectedTab = 0
        return .none

      case let .home(.delegate(.feedCategorySelected(category))):
        state.feed = FeedFeature.State(category: category)
        state.selectedTab = 1
        return .none

      case .home:
        return .none

      case .logoutButtonTapped:
        return .send(.delegate(.logoutRequested))

      case .delegate:
        return .none
      }
    }
  }
}
