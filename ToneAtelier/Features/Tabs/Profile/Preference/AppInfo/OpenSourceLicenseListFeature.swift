//
//  OpenSourceLicenseListFeature.swift
//  ToneAtelier
//
//  Created by Codex on 5/2/26.
//

import ComposableArchitecture
import Foundation

// TODO: 라이선스 자동 수집 도구(LicensePlist 등) 도입 후 mock을 실제 산출물 매핑으로 교체.
//   현재는 SPM Build Tool Plug-in의 sandbox 제약으로 자동 수집이 어려워 정적 mock을 사용한다.
//   대안: Run Script Phase로 license-plist cli 직접 호출 → 산출물 plist를 main bundle에 포함.
@Reducer
struct OpenSourceLicenseListFeature {
  @ObservableState
  struct State: Equatable {
    var entries: [LicenseEntry] = []
    var hasLoaded = false
    /// 펼쳐서 라이선스 본문을 보여주는 항목 식별자.
    var expandedIDs: Set<String> = []
  }

  enum Action: Sendable {
    case task
    case toggleExpanded(id: String)
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .task:
        guard !state.hasLoaded else { return .none }
        state.entries = LicenseEntry.mock
        state.hasLoaded = true
        return .none

      case let .toggleExpanded(id):
        if state.expandedIDs.contains(id) {
          state.expandedIDs.remove(id)
        } else {
          state.expandedIDs.insert(id)
        }
        return .none
      }
    }
  }
}

// MARK: - Entry Model

struct LicenseEntry: Equatable, Identifiable, Sendable {
  let id: String
  let title: String
  let body: String
}

extension LicenseEntry {
  /// 자동 수집 도입 전까지 사용하는 정적 mock. 실제 라이선스 본문이 아닌 요약만 포함한다.
  static let mock: [LicenseEntry] = [
    LicenseEntry(
      id: "swift-composable-architecture",
      title: "swift-composable-architecture",
      body: "MIT License — Point-Free, Inc."
    ),
    LicenseEntry(
      id: "firebase-ios-sdk",
      title: "Firebase iOS SDK",
      body: "Apache License 2.0 — Google LLC"
    ),
    LicenseEntry(
      id: "kakao-ios-sdk",
      title: "Kakao iOS SDK",
      body: "Apache License 2.0 — Kakao Corp."
    ),
    LicenseEntry(
      id: "iamport-ios",
      title: "iamport-ios",
      body: "Apache License 2.0 — NHN KCP / Iamport"
    ),
    LicenseEntry(
      id: "socket.io-client-swift",
      title: "Socket.IO Client Swift",
      body: "MIT License — Erik Little"
    ),
  ]
}
