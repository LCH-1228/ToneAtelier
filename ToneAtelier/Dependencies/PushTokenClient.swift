//
//  PushTokenClient.swift
//  ToneAtelier
//
//  Created by Codex on 5/2/26.
//

import ComposableArchitecture
import Foundation

struct PushTokenClient {
  var current: @Sendable () async -> String?
  var update: @Sendable (_ token: String?) async -> Void
  /// FCM이 새 토큰을 발급/회전했을 때만 yield된다. 토큰 무효화/clear는 yield하지 않는다.
  var tokenUpdates: @Sendable () -> AsyncStream<String>
  var clear: @Sendable () async -> Void
}

extension PushTokenClient: DependencyKey {
  static let liveValue: PushTokenClient = {
    let center = LivePushTokenCenter.shared

    return PushTokenClient(
      current: {
        await center.current()
      },
      update: { token in
        await center.update(token)
      },
      tokenUpdates: {
        AsyncStream { continuation in
          let task = Task {
            let stream = await center.tokenUpdates()
            for await token in stream {
              continuation.yield(token)
            }
            continuation.finish()
          }

          continuation.onTermination = { _ in
            task.cancel()
          }
        }
      },
      clear: {
        await center.clear()
      }
    )
  }()

  static let testValue = PushTokenClient(
    current: { nil },
    update: { _ in },
    tokenUpdates: { AsyncStream { _ in } },
    clear: {}
  )
}

extension DependencyValues {
  var pushTokenClient: PushTokenClient {
    get { self[PushTokenClient.self] }
    set { self[PushTokenClient.self] = newValue }
  }
}

actor LivePushTokenCenter {
  static let shared = LivePushTokenCenter()

  private let store: KeychainPushTokenStore
  private var tokenContinuations: [UUID: AsyncStream<String>.Continuation] = [:]

  init(store: KeychainPushTokenStore = KeychainPushTokenStore()) {
    self.store = store
  }

  func current() async -> String? {
    await store.read()
  }

  func update(_ token: String?) async {
    await store.update(token)

    // nil은 토큰 삭제 신호이므로 구독자에게 yield하지 않는다.
    guard let token else { return }

    let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }

    for continuation in tokenContinuations.values {
      continuation.yield(trimmed)
    }
  }

  func tokenUpdates() -> AsyncStream<String> {
    let id = UUID()
    let stream = AsyncStream.makeStream(of: String.self)

    // dictionary 등록을 onTermination 콜백 설정보다 먼저 수행해야
    // 즉시 종료 시에도 leak 없이 정리된다.
    tokenContinuations[id] = stream.continuation
    stream.continuation.onTermination = { _ in
      Task {
        await self.removeContinuation(id: id)
      }
    }

    return stream.stream
  }

  func clear() async {
    await store.clear()
  }

  private func removeContinuation(id: UUID) {
    tokenContinuations.removeValue(forKey: id)
  }
}
