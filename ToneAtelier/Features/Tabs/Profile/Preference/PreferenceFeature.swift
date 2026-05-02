//
//  PreferenceFeature.swift
//  ToneAtelier
//
//  Created by Codex on 5/2/26.
//

import ComposableArchitecture
import Foundation
import UIKit
import UserNotifications

// TODO: APP INFO 화면 구현 시 처리 사항
//   - 앱 이름: Bundle CFBundleDisplayName / CFBundleName 동적 추출
//   - 이용 약관: path 명세 확정 후 commonClient.makeWebViewRequest 연동
//   - 오픈소스 라이선스: LicensePlist 등 자동화 도구 도입 검토

// 별도 dependency 분리 없이 reducer 안에서 UNUserNotificationCenter / UIApplication을 직접 호출.
// 단일 화면 안에서만 쓰고, 권한 토글은 시스템 prompt + 시스템 설정 외 분기점이 없어 점층적 도입 비용이 큼.
@Reducer
struct PreferenceFeature {
  @ObservableState
  struct State: Equatable {
    var summary: ProfileSummary
    var pushAuthorizationStatus: UNAuthorizationStatus = .notDetermined
    var editProfile: ProfileEditFeature.State?
  }

  enum Action: Sendable {
    case task
    case authorizationStatusFetched(UNAuthorizationStatus)
    case profileCardTapped
    case pushNotificationToggleTapped
    case requestAuthorizationCompleted
    case openSystemSettingsCompleted
    case purchaseHistoryTapped
    case logoutTapped
    case editProfile(ProfileEditFeature.Action)
    case editProfileDismissed
    case delegate(Delegate)

    enum Delegate: Equatable, Sendable {
      case logoutRequested
    }
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .task:
        return .run { send in
          let settings = await UNUserNotificationCenter.current().notificationSettings()
          await send(.authorizationStatusFetched(settings.authorizationStatus))
        }

      case let .authorizationStatusFetched(status):
        state.pushAuthorizationStatus = status
        return .none

      case .profileCardTapped:
        state.editProfile = ProfileEditFeature.State(
          nickname: state.summary.nickname,
          email: state.summary.email,
          name: state.summary.name,
          phoneNum: state.summary.phoneNum ?? "",
          introduction: state.summary.bio,
          hashTags: state.summary.hashTags,
          avatarURL: state.summary.avatarURL
        )
        return .none

      case .pushNotificationToggleTapped:
        switch state.pushAuthorizationStatus {
        case .notDetermined:
          return .run { send in
            _ = try? await UNUserNotificationCenter.current()
              .requestAuthorization(options: [.alert, .badge, .sound])
            await send(.requestAuthorizationCompleted)
          }
        default:
          return .run { send in
            if let url = URL(string: UIApplication.openSettingsURLString) {
              await UIApplication.shared.open(url)
            }
            await send(.openSystemSettingsCompleted)
          }
        }

      case .requestAuthorizationCompleted:
        // 사용자가 prompt에서 거부해도 toggle 표시가 즉시 갱신되도록 status 재조회.
        return .run { send in
          let settings = await UNUserNotificationCenter.current().notificationSettings()
          await send(.authorizationStatusFetched(settings.authorizationStatus))
        }

      case .openSystemSettingsCompleted:
        return .none

      case .purchaseHistoryTapped:
        return .none

      case .logoutTapped:
        return .send(.delegate(.logoutRequested))

      case let .editProfile(.delegate(.profileUpdated(saved))):
        // 편집 화면에서 저장한 변경분을 Preference의 summary에도 반영해
        // 프로필 카드/로그아웃 셀의 email 표시가 stale 상태가 되지 않게 한다.
        state.summary.nickname = saved.nickname
        state.summary.bio = saved.introduction
        state.summary.phoneNum = saved.phoneNum.isEmpty ? nil : saved.phoneNum
        state.summary.hashTags = saved.hashTags
        state.summary.avatarURL = saved.avatarURL
        state.editProfile = nil
        return .none

      case .editProfile(.delegate(.dismissRequested)):
        state.editProfile = nil
        return .none

      case .editProfile:
        return .none

      case .editProfileDismissed:
        state.editProfile = nil
        return .none

      case .delegate:
        return .none
      }
    }
    .ifLet(\.editProfile, action: \.editProfile) {
      ProfileEditFeature()
    }
  }
}
