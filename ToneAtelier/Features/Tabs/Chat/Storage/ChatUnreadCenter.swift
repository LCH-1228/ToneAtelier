//
//  ChatUnreadCenter.swift
//  ToneAtelier
//
//  Created by Codex on 5/8/26.
//

import ComposableArchitecture
import Foundation
import UserNotifications

// MARK: - Center actor

/// 채팅 unread 카운트의 단일 진실 원천(SSOT).
///
/// 책임:
/// - in-memory `[roomID: Int]` 보유 + SwiftData 영속 sync
/// - 변경 시 모든 구독자에게 `AsyncStream<[String: Int]>` broadcast
/// - foreground push: increment + 해당 알림 센터 entry 즉시 제거
/// - background → foreground 복귀: catchUp() 이 알림 센터 entries 를 흡수 후 제거
/// - 채팅방 진입: clear(roomID) + 해당 room 알림 센터 entry 일괄 제거
/// - 앱 아이콘 배지(setBadgeCount) 동기화는 모든 변경 직후 수행
///
/// 서버 push payload는 `room_id` 만 보장되므로 모든 분류는 `userInfo["room_id"]` 기준.
actor LiveChatUnreadCenter {
  static let shared = LiveChatUnreadCenter()

  private var counts: [String: Int] = [:]
  private var bootstrapped = false
  private var continuations: [UUID: AsyncStream<[String: Int]>.Continuation] = [:]

  // MARK: - Bootstrap

  func bootstrap(loader: @Sendable () async throws -> [String: Int]) async {
    if bootstrapped {
      broadcast()
      await applyBadgeCount()
      return
    }
    bootstrapped = true
    if let initial = try? await loader() {
      counts = initial
    }
    broadcast()
    await applyBadgeCount()
  }

  func snapshot() -> [String: Int] {
    counts
  }

  // MARK: - Mutations

  func increment(
    roomID: String,
    notificationID: String?,
    persist: @Sendable (String) async throws -> Void
  ) async {
    counts[roomID, default: 0] += 1
    try? await persist(roomID)
    if let notificationID {
      UNUserNotificationCenter.current()
        .removeDeliveredNotifications(withIdentifiers: [notificationID])
    }
    broadcast()
    await applyBadgeCount()
  }

  func clear(
    roomID: String,
    persist: @Sendable (String) async throws -> Void
  ) async {
    let removedFromMemory = counts.removeValue(forKey: roomID) != nil
    try? await persist(roomID)
    let identifiers = await deliveredNotificationIDs(for: roomID)
    if !identifiers.isEmpty {
      UNUserNotificationCenter.current()
        .removeDeliveredNotifications(withIdentifiers: identifiers)
    }
    if removedFromMemory || !identifiers.isEmpty {
      broadcast()
      await applyBadgeCount()
    }
  }

  func catchUp(
    persist: @Sendable ([String: Int]) async throws -> Void
  ) async {
    let delivered = await UNUserNotificationCenter.current().deliveredNotifications()
    guard !delivered.isEmpty else { return }
    var identifiersToRemove: [String] = []
    var changed = false
    for notification in delivered {
      guard let roomID = notification.request.content.userInfo["room_id"] as? String else {
        continue
      }
      counts[roomID, default: 0] += 1
      identifiersToRemove.append(notification.request.identifier)
      changed = true
    }
    if !identifiersToRemove.isEmpty {
      UNUserNotificationCenter.current()
        .removeDeliveredNotifications(withIdentifiers: identifiersToRemove)
    }
    guard changed else { return }
    try? await persist(counts)
    broadcast()
    await applyBadgeCount()
  }

  func clearAll(
    persist: @Sendable () async throws -> Void
  ) async {
    counts = [:]
    bootstrapped = false
    try? await persist()
    UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    broadcast()
    await applyBadgeCount()
  }

  // MARK: - Stream

  func registerContinuation(_ continuation: AsyncStream<[String: Int]>.Continuation) -> UUID {
    let id = UUID()
    continuations[id] = continuation
    continuation.yield(counts)
    return id
  }

  func removeContinuation(id: UUID) {
    continuations.removeValue(forKey: id)
  }

  // MARK: - Private

  private func broadcast() {
    let snapshot = counts
    for continuation in continuations.values {
      continuation.yield(snapshot)
    }
  }

  private func applyBadgeCount() async {
    let total = counts.values.reduce(0, +)
    try? await UNUserNotificationCenter.current().setBadgeCount(total)
  }

  private func deliveredNotificationIDs(for roomID: String) async -> [String] {
    let delivered = await UNUserNotificationCenter.current().deliveredNotifications()
    return delivered.compactMap { notification in
      guard let id = notification.request.content.userInfo["room_id"] as? String,
            id == roomID else { return nil }
      return notification.request.identifier
    }
  }
}

// MARK: - Dependency Client

struct ChatUnreadCenterClient {
  /// 앱 부트스트랩 시 1회. SwiftData 영속값을 메모리에 적재 후 broadcast.
  var bootstrap: @Sendable () async -> Void
  /// 현재 in-memory 스냅샷.
  var snapshot: @Sendable () async -> [String: Int]
  /// foreground push 도착. 알림 센터 entry 즉시 제거 시도.
  var increment: @Sendable (_ roomID: String, _ notificationID: String?) async -> Void
  /// 채팅방 진입. 해당 room 알림 센터 entry 일괄 제거.
  var clear: @Sendable (_ roomID: String) async -> Void
  /// foreground 복귀. 알림 센터 entries 를 흡수 후 제거.
  var catchUp: @Sendable () async -> Void
  /// 로그아웃/세션 만료. 모든 카운트 + 알림 센터 entry 제거.
  var clearAll: @Sendable () async -> Void
  /// 변경 broadcast 스트림. 구독 시 즉시 현재 스냅샷 1회 yield.
  var stream: @Sendable () -> AsyncStream<[String: Int]>
}

extension ChatUnreadCenterClient: DependencyKey {
  static var liveValue: ChatUnreadCenterClient {
    let center = LiveChatUnreadCenter.shared
    return ChatUnreadCenterClient(
      bootstrap: {
        @Dependency(\.chatLocalStore) var chatLocalStore
        let store = chatLocalStore
        await center.bootstrap { try await store.loadUnreadCounts() }
      },
      snapshot: {
        await center.snapshot()
      },
      increment: { roomID, notificationID in
        @Dependency(\.chatLocalStore) var chatLocalStore
        let store = chatLocalStore
        await center.increment(
          roomID: roomID,
          notificationID: notificationID,
          persist: { try await store.incrementUnread($0) }
        )
      },
      clear: { roomID in
        @Dependency(\.chatLocalStore) var chatLocalStore
        let store = chatLocalStore
        await center.clear(
          roomID: roomID,
          persist: { try await store.clearUnread($0) }
        )
      },
      catchUp: {
        @Dependency(\.chatLocalStore) var chatLocalStore
        let store = chatLocalStore
        await center.catchUp(persist: { try await store.replaceUnreadCounts($0) })
      },
      clearAll: {
        @Dependency(\.chatLocalStore) var chatLocalStore
        let store = chatLocalStore
        await center.clearAll(persist: { try await store.replaceUnreadCounts([:]) })
      },
      stream: {
        AsyncStream { continuation in
          let registerTask = Task { await center.registerContinuation(continuation) }
          continuation.onTermination = { _ in
            Task {
              let id = await registerTask.value
              await center.removeContinuation(id: id)
            }
          }
        }
      }
    )
  }

  static let testValue = ChatUnreadCenterClient(
    bootstrap: {},
    snapshot: { [:] },
    increment: { _, _ in },
    clear: { _ in },
    catchUp: {},
    clearAll: {},
    stream: { AsyncStream { _ in } }
  )
}

extension DependencyValues {
  var chatUnreadCenter: ChatUnreadCenterClient {
    get { self[ChatUnreadCenterClient.self] }
    set { self[ChatUnreadCenterClient.self] = newValue }
  }
}
