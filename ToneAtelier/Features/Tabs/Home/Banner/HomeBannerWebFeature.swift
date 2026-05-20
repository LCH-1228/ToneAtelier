//
//  HomeBannerWebFeature.swift
//  ToneAtelier
//
//  Created by Codex on 4/25/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct HomeBannerWebFeature {
  @ObservableState
  struct State: Equatable {
    @Presents var alert: AlertState<Action.Alert>?
    let title: String
    let webViewRequest: WebViewRequest
    let accessToken: String
  }

  enum Action: Sendable {
    case alert(PresentationAction<Alert>)
    case attendanceCompleted(Int?)
    case closeButtonTapped
    case delegate(Delegate)

    enum Alert: Equatable, Sendable {}

    enum Delegate: Equatable, Sendable {
      case dismissRequested
    }
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .alert:
        return .none

      case let .attendanceCompleted(count):
        state.alert = AlertState {
          TextState("출석 완료")
        } actions: {
          ButtonState(role: .cancel) {
            TextState("확인")
          }
        } message: {
          if let count {
            TextState("\(count)번째 출석이 완료되었습니다.")
          } else {
            TextState("출석이 완료되었습니다.")
          }
        }
        return .none

      case .closeButtonTapped:
        return .send(.delegate(.dismissRequested))

      case .delegate:
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
  }
}
