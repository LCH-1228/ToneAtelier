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
    if let accessToken, !accessToken.trimmed.isEmpty {
      snapshotValue.accessToken = accessToken
    }

    if let refreshToken, !refreshToken.trimmed.isEmpty {
      snapshotValue.refreshToken = refreshToken
    }
  }
}

struct SessionClient {
  var snapshot: @Sendable () async -> SessionSnapshot
}

extension SessionClient: DependencyKey {
  static let liveValue: SessionClient = {
    let storage = LiveNetworkSessionStorage.storage

    return SessionClient(
      snapshot: {
        await storage.snapshot()
      }
    )
  }()

  static let testValue = SessionClient(
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
