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
    var selectedTab = 0
  }

  enum Action: BindableAction, Sendable {
    case binding(BindingAction<State>)
    case delegate(Delegate)
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

    BindingReducer()

    Reduce { state, action in
      switch action {
      case .binding:
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
