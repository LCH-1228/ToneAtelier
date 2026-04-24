//
//  LoginFeatureTests.swift
//  ToneAtelierTests
//
//  Created by Codex on 4/24/26.
//

import ComposableArchitecture
import XCTest
@testable import ToneAtelier

@MainActor
final class LoginFeatureTests: XCTestCase {

  func testNoticeDismissedClearsNotice() async {
    let store = TestStore(
      initialState: LoginFeature.State(notice: .sessionExpired)
    ) {
      LoginFeature()
    }

    await store.send(.noticeDismissed) {
      $0.notice = nil
    }
  }

  func testLoginButtonTappedClearsNoticeBeforeValidation() async {
    let store = TestStore(
      initialState: LoginFeature.State(notice: .reauthenticationRequired)
    ) {
      LoginFeature()
    }

    await store.send(.loginButtonTapped) {
      $0.notice = nil
      $0.alert = AlertState {
        TextState("아이디를 입력해 주세요.")
      }
    }
  }
}
