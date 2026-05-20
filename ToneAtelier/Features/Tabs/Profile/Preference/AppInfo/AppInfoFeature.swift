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
    var termsOfService: TermsOfServiceFeature.State?
    @Presents var alert: AlertState<Action.Alert>?
  }

  enum Action: Sendable {
    case termsOfServiceTapped
    case termsOfService(TermsOfServiceFeature.Action)
    case termsOfServiceDismissed
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
        state.termsOfService = TermsOfServiceFeature.State()
        return .none

      case .termsOfService:
        return .none

      case .termsOfServiceDismissed:
        state.termsOfService = nil
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
    .ifLet(\.termsOfService, action: \.termsOfService) {
      TermsOfServiceFeature()
    }
  }
}
