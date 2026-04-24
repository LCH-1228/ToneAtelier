//
//  SessionClient.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import ComposableArchitecture
import Foundation

enum SessionEvent: Equatable, Sendable {
  case invalidated
}

struct SessionClient {
  var clearTokens: @Sendable () async -> Void
  var events: @Sendable () async -> AsyncStream<SessionEvent>
  var invalidateSession: @Sendable () async -> Void
  var snapshot: @Sendable () async -> SessionSnapshot
  var updateTokens: @Sendable (_ accessToken: String?, _ refreshToken: String?) async -> Void
}

extension SessionClient: DependencyKey {
  static let liveValue: SessionClient = {
    let storage = LiveSessionCenter.shared

    return SessionClient(
      clearTokens: {
        await storage.clearTokens()
      },
      events: {
        await storage.events()
      },
      invalidateSession: {
        await storage.invalidateSession()
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
    events: {
      AsyncStream { _ in }
    },
    invalidateSession: {},
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
    invalidateSession: {},
    loadSession: {
      await MainActor.run {
        SessionSnapshot.empty
      }
    },
    refreshTokens: {
      throw APIError.transport("HTTPClient.refreshTokens testValue")
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

actor LiveSessionCenter {
  static let shared = LiveSessionCenter()

  private let store = KeychainSessionStore()
  private var eventContinuations: [UUID: AsyncStream<SessionEvent>.Continuation] = [:]

  func clearTokens() async {
    await store.clearTokens()
  }

  func events() -> AsyncStream<SessionEvent> {
    let id = UUID()
    let stream = AsyncStream.makeStream(of: SessionEvent.self)

    stream.continuation.onTermination = { _ in
      Task {
        await self.removeContinuation(id: id)
      }
    }

    eventContinuations[id] = stream.continuation
    return stream.stream
  }

  func invalidateSession() async {
    await store.clearTokens()

    for continuation in eventContinuations.values {
      continuation.yield(.invalidated)
    }
  }

  func snapshot() async -> SessionSnapshot {
    await store.snapshot()
  }

  func updateTokens(accessToken: String?, refreshToken: String?) async {
    await store.updateTokens(
      accessToken: accessToken,
      refreshToken: refreshToken
    )
  }

  private func removeContinuation(id: UUID) {
    eventContinuations.removeValue(forKey: id)
  }
}
