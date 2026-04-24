//
//  SessionClient.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import ComposableArchitecture
import Foundation

struct SessionClient {
  var clearTokens: @Sendable () async -> Void
  var snapshot: @Sendable () async -> SessionSnapshot
  var updateTokens: @Sendable (_ accessToken: String?, _ refreshToken: String?) async -> Void
}

extension SessionClient: DependencyKey {
  static let liveValue: SessionClient = {
    let storage = LiveSessionStore.shared

    return SessionClient(
      clearTokens: {
        await storage.clearTokens()
      },
      snapshot: {
        await storage.snapshot()
      },
      updateTokens: { accessToken, refreshToken in
        await storage.updateTokens(
          accessToken: accessToken,
          refreshToken: refreshToken
        )
      }
    )
  }()

  static let testValue = SessionClient(
    clearTokens: {},
    snapshot: {
      await MainActor.run {
        SessionSnapshot.empty
      }
    },
    updateTokens: { _, _ in }
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
    loadSession: {
      await MainActor.run {
        SessionSnapshot.empty
      }
    },
    updateTokens: { _, _ in }
  )
}

extension DependencyValues {
  var httpClient: HTTPClient {
    get { self[HTTPClient.self] }
    set { self[HTTPClient.self] = newValue }
  }
}
