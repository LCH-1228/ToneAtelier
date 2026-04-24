//
//  SessionClient.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import ComposableArchitecture
import Foundation

actor SessionStorage {
  private var snapshotValue: SessionSnapshot = .default

  func snapshot() -> SessionSnapshot {
    snapshotValue
  }

  func updateTokens(accessToken: String?, refreshToken: String?) {
    if let accessToken, SessionStorage.hasText(accessToken) {
      snapshotValue.accessToken = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    if let refreshToken, SessionStorage.hasText(refreshToken) {
      snapshotValue.refreshToken = refreshToken.trimmingCharacters(in: .whitespacesAndNewlines)
    }
  }

  func clearTokens() {
    snapshotValue.accessToken = ""
    snapshotValue.refreshToken = ""
  }

  private static func hasText(_ value: String) -> Bool {
    !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
}

struct SessionClient {
  var clearTokens: @Sendable () async -> Void
  var snapshot: @Sendable () async -> SessionSnapshot
}

extension SessionClient: DependencyKey {
  static let liveValue: SessionClient = {
    let storage = LiveNetworkSessionStorage.storage

    return SessionClient(
      clearTokens: {
        await storage.clearTokens()
      },
      snapshot: {
        await storage.snapshot()
      }
    )
  }()

  static let testValue = SessionClient(
    clearTokens: {},
    snapshot: { .default }
  )
}

extension DependencyValues {
  var sessionClient: SessionClient {
    get { self[SessionClient.self] }
    set { self[SessionClient.self] = newValue }
  }
}

extension HTTPClient: DependencyKey {
  static let liveValue = HTTPClient.live

  static let testValue = HTTPClient(
    execute: { _ in
      throw APIError.transport("TestValue로 교체되지 않은 HTTPClient입니다.")
    },
    loadSession: { .default },
    updateTokens: { _, _ in }
  )
}

extension DependencyValues {
  var httpClient: HTTPClient {
    get { self[HTTPClient.self] }
    set { self[HTTPClient.self] = newValue }
  }
}
