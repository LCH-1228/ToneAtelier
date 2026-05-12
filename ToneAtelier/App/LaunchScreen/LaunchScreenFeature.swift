//
//  LaunchScreenFeature.swift
//  ToneAtelier
//
//  Created by Codex on 5/12/26.
//

import ComposableArchitecture

@Reducer
struct LaunchScreenFeature {
  @ObservableState
  struct State: Equatable {}

  enum Action: Sendable {
    case task
  }

  var body: some Reducer<State, Action> {
    Reduce { _, action in
      switch action {
      case .task:
        return .none
      }
    }
  }
}
