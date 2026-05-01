//
//  SessionClient.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import ComposableArchitecture
import Foundation
import OSLog

enum SessionInvalidationReason: Equatable, Sendable {
  case accessTokenRejected(statusCode: Int)
  case refreshTokenRejected(statusCode: Int)
  case expired(statusCode: Int)

  nonisolated var logCode: String {
    switch self {
    case let .accessTokenRejected(statusCode):
      return "access_token_rejected_\(statusCode)"
    case let .refreshTokenRejected(statusCode):
      return "refresh_token_rejected_\(statusCode)"
    case let .expired(statusCode):
      return "session_expired_\(statusCode)"
    }
  }
}

enum SessionEvent: Equatable, Sendable {
  case invalidated(SessionInvalidationReason)
  /// 401/418 retry 흐름에서 access/refresh 토큰이 새 값으로 교체된 직후 yield된다.
  /// 구독자는 새 SessionSnapshot을 다시 읽어 인증 자원이 필요한 장기 연결(예: 채팅 socket)을
  /// 새 토큰으로 재연결할 수 있다.
  case tokenRefreshed
}

struct SessionClient {
  var clearTokens: @Sendable () async -> Void
  var currentGeneration: @Sendable () async -> UInt64
  var events: @Sendable () async -> AsyncStream<SessionEvent>
  var invalidateSession: @Sendable (_ reason: SessionInvalidationReason) async -> Void
  var snapshot: @Sendable () async -> SessionSnapshot
  var updateTokens: @Sendable (_ accessToken: String?, _ refreshToken: String?) async -> Void
  var updateCurrentUserID: @Sendable (_ userID: String?) async -> Void
}

extension SessionClient: DependencyKey {
  static let liveValue: SessionClient = {
    let storage = LiveSessionCenter.shared

    return SessionClient(
      clearTokens: {
        await storage.clearTokens()
      },
      currentGeneration: {
        await storage.currentGeneration()
      },
      events: {
        await storage.events()
      },
      invalidateSession: { reason in
        await storage.invalidateSession(reason: reason)
      },
      snapshot: {
        await storage.snapshot()
      },
      updateTokens: { accessToken, refreshToken in
        await storage.updateTokens(
          accessToken: accessToken,
          refreshToken: refreshToken
        )
      },
      updateCurrentUserID: { userID in
        await storage.updateCurrentUserID(userID)
      }
    )
  }()

  static let testValue = SessionClient(
    clearTokens: {},
    currentGeneration: { 0 },
    events: {
      AsyncStream { _ in }
    },
    invalidateSession: { _ in },
    snapshot: {
      await MainActor.run {
        SessionSnapshot.empty
      }
    },
    updateTokens: { _, _ in },
    updateCurrentUserID: { _ in }
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
    currentSessionGeneration: { 0 },
    invalidateSession: { _ in },
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

  private let store: KeychainSessionStore
  private var currentRefreshTask: Task<TokenRefreshResponse, Error>?
  private var eventContinuations: [UUID: AsyncStream<SessionEvent>.Continuation] = [:]
  private var generation: UInt64 = 0

  init(store: KeychainSessionStore = KeychainSessionStore()) {
    self.store = store
  }

  func clearTokens() async {
    generation += 1
    currentRefreshTask?.cancel()
    currentRefreshTask = nil
    await store.clearTokens()
  }

  func currentGeneration() -> UInt64 {
    generation
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

  func invalidateSession(reason: SessionInvalidationReason) async {
    generation += 1
    currentRefreshTask?.cancel()
    currentRefreshTask = nil
    await store.clearTokens()

    let reasonLogCode = reason.logCode
    Logger.authSession.notice("Session invalidated: \(reasonLogCode, privacy: .public)")

    for continuation in eventContinuations.values {
      continuation.yield(.invalidated(reason))
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

  func updateCurrentUserID(_ userID: String?) async {
    await store.updateCurrentUserID(userID)
  }

  func refreshTokens(
    using operation: @Sendable @escaping () async throws -> TokenRefreshResponse
  ) async throws -> TokenRefreshResponse {
    if let currentRefreshTask {
      Logger.authSession.debug("Token refresh: joining existing task")
      return try await currentRefreshTask.value
    }

    Logger.authSession.notice("Token refresh started")

    let generationAtStart = generation
    let refreshTask = Task {
      try await operation()
    }

    currentRefreshTask = refreshTask
    defer {
      currentRefreshTask = nil
    }

    let tokens = try await refreshTask.value
    guard generationAtStart == generation else {
      Logger.authSession.debug("Token refresh result discarded: session generation changed during refresh")
      throw CancellationError()
    }

    Logger.authSession.notice("Token refresh succeeded")

    await store.updateTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken
    )

    // 토큰 갱신 직후 모든 구독자에게 알린다. 채팅 socket 등 장기 연결을 가진 화면이
    // 새 snapshot으로 자동 재연결할 수 있도록 한다.
    for continuation in eventContinuations.values {
      continuation.yield(.tokenRefreshed)
    }

    return tokens
  }

  private func removeContinuation(id: UUID) {
    eventContinuations.removeValue(forKey: id)
  }
}
