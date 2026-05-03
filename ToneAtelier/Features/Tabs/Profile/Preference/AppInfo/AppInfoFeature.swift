//
//  AppInfoFeature.swift
//  ToneAtelier
//
//  Created by Codex on 5/2/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct AppInfoFeature {
  @ObservableState
  struct State: Equatable {
    var licenseList: OpenSourceLicenseListFeature.State?
    @Presents var alert: AlertState<Action.Alert>?
  }

  enum Action: Sendable {
    case termsOfServiceTapped
    case openSourceLicenseTapped
    case licenseList(OpenSourceLicenseListFeature.Action)
    case licenseListDismissed
    case alert(PresentationAction<Alert>)

    enum Alert: Equatable, Sendable {}
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .termsOfServiceTapped:
        // 이용 약관 path 명세가 확정되지 않아 임시로 안내 alert 표시.
        state.alert = AlertState {
          TextState("준비 중")
        } message: {
          TextState("이용 약관 페이지는 곧 제공될 예정입니다.")
        }
        return .none

      case .openSourceLicenseTapped:
        state.licenseList = OpenSourceLicenseListFeature.State()
        return .none

      case .licenseList:
        return .none

      case .licenseListDismissed:
        state.licenseList = nil
        return .none

      case .alert:
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
    .ifLet(\.licenseList, action: \.licenseList) {
      OpenSourceLicenseListFeature()
    }
  }
}
