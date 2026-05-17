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
  struct State: Equatable {
    fileprivate var hasFiredReady = false
  }

  enum Action: Sendable {
    case delegate(Delegate)
    case minimumDurationElapsed
    case task

    enum Delegate: Equatable, Sendable {
      case ready
    }
  }

  @Dependency(\.continuousClock) private var clock

  static let minimumDisplayDuration: Duration = .seconds(1.5)

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .delegate:
        return .none

      case .minimumDurationElapsed:
        guard !state.hasFiredReady else { return .none }
        state.hasFiredReady = true
        return .send(.delegate(.ready))

      case .task:
        let clock = clock
        return .run { send in
          try? await clock.sleep(for: Self.minimumDisplayDuration)
          await send(.minimumDurationElapsed)
        }
      }
    }
  }
}
