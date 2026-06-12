//
//  ChatUnreadCenter.swift
//  ToneAtelier
//
//  Created by Codex on 5/8/26.
//

import ComposableArchitecture
import Foundation
import OSLog
import UserNotifications

// MARK: - Center actor

/// 채팅 unread 카운트의 단일 진실 원천(SSOT).
///
/// 책임:
/// - in-memory `[roomID: Int]` 보유 + SwiftData 영속 sync
/// - 변경 시 모든 구독자에게 `AsyncStream<[String: Int]>` broadcast
/// - foreground push: increment + 식별자 dedup set 등록 (catch-up 시 재흡수 방어)
/// - background → foreground 복귀: catchUp() 이 알림 센터 entries 중 dedup set 에 없는 것만 흡수
/// - 채팅방 진입: clear(roomID) + 해당 room 알림 센터 entry 일괄 제거
/// - 앱 아이콘 배지(setBadgeCount) 동기화는 모든 변경 직후 수행
///
/// 서버 push payload는 `room_id` 만 보장되므로 모든 분류는 `userInfo["room_id"]` 기준.
///
/// dedup set(`processedIdentifiers`)은 `removeDeliveredNotifications` 의 race
/// (foreground 처리 직후 entry 가 알림 센터에 잔존) 와 무관하게 catch-up 이 같은 알림을
/// 두 번 카운트하지 않도록 보장한다. cold launch 후에도 유효해야 하므로 UserDefaults 에 persist.
actor LiveChatUnreadCenter {
  static let shared = LiveChatUnreadCenter()

  private static let processedIdentifiersKey = "chatUnread.processedIdentifiers"
  /// dedup set 의 최대 보존 기간. 알림 센터 entry 는 OS 정책상 수일 안에 자연 소거되므로 24h 이면 충분.
  private static let processedTTL: TimeInterval = 60 * 60 * 24

  private var counts: [String: Int] = [:]
  private var bootstrapped = false
  private var continuations: [UUID: AsyncStream<[String: Int]>.Continuation] = [:]
  /// notificationID → 처리 시각. catch-up 시 이미 흡수한 알림을 재카운트하지 않기 위함.
  private var processedIdentifiers: [String: Date] = [:]

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
    loadProcessedIdentifiers()
    pruneProcessedIdentifiers()
    let total = totalForLog
    let processed = processedIdentifiers.count
    Logger.chatUnread.notice(
      "bootstrap done total=\(total, privacy: .public) processed=\(processed, privacy: .public)"
    )
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
    if let notificationID, processedIdentifiers[notificationID] != nil {
      return
    }
    counts[roomID, default: 0] += 1
    try? await persist(roomID)
    if let notificationID {
      processedIdentifiers[notificationID] = Date()
      saveProcessedIdentifiers()
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
      for id in identifiers {
        processedIdentifiers.removeValue(forKey: id)
      }
      saveProcessedIdentifiers()
    }
    if removedFromMemory || !identifiers.isEmpty {
      broadcast()
      await applyBadgeCount()
    }
  }

  func catchUp(
    persist: @Sendable ([String: Int]) async throws -> Void
  ) async {
    pruneProcessedIdentifiers()
    let delivered = await UNUserNotificationCenter.current().deliveredNotifications()
    guard !delivered.isEmpty else { return }
    var identifiersToRemove: [String] = []
    var absorbed = 0
    var skippedDup = 0
    for notification in delivered {
      let id = notification.request.identifier
      identifiersToRemove.append(id)
      if processedIdentifiers[id] != nil {
        skippedDup += 1
        continue
      }
      guard let roomID = notification.request.content.userInfo["room_id"] as? String else {
        continue
      }
      counts[roomID, default: 0] += 1
      processedIdentifiers[id] = Date()
      absorbed += 1
    }
    if !identifiersToRemove.isEmpty {
      UNUserNotificationCenter.current()
        .removeDeliveredNotifications(withIdentifiers: identifiersToRemove)
    }
    saveProcessedIdentifiers()
    let total = totalForLog
    Logger.chatUnread.notice("""
      catchUp absorbed=\(absorbed, privacy: .public) \
      dup=\(skippedDup, privacy: .public) \
      total=\(total, privacy: .public)
      """)
    guard absorbed > 0 else { return }
    try? await persist(counts)
    broadcast()
    await applyBadgeCount()
  }

  func clearAll(
    persist: @Sendable () async throws -> Void
  ) async {
    counts = [:]
    bootstrapped = false
    processedIdentifiers = [:]
    UserDefaults.standard.removeObject(forKey: Self.processedIdentifiersKey)
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

  private var totalForLog: Int {
    counts.values.reduce(0, +)
  }

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

  private func loadProcessedIdentifiers() {
    guard let raw = UserDefaults.standard.dictionary(forKey: Self.processedIdentifiersKey) as? [String: Double] else {
      return
    }
    var restored: [String: Date] = [:]
    for (id, ts) in raw {
      restored[id] = Date(timeIntervalSince1970: ts)
    }
    processedIdentifiers = restored
  }

  private func saveProcessedIdentifiers() {
    var serialized: [String: Double] = [:]
    for (id, date) in processedIdentifiers {
      serialized[id] = date.timeIntervalSince1970
    }
    UserDefaults.standard.set(serialized, forKey: Self.processedIdentifiersKey)
  }

  private func pruneProcessedIdentifiers() {
    let cutoff = Date().addingTimeInterval(-Self.processedTTL)
    let beforeCount = processedIdentifiers.count
    processedIdentifiers = processedIdentifiers.filter { $0.value >= cutoff }
    if processedIdentifiers.count != beforeCount {
      saveProcessedIdentifiers()
    }
  }
}

// MARK: - Dependency Client

struct ChatUnreadCenterClient {
  /// 앱 부트스트랩 시 1회. SwiftData 영속값을 메모리에 적재 + UserDefaults dedup set 복원 + broadcast.
  var bootstrap: @Sendable () async -> Void
  /// 현재 in-memory 스냅샷.
  var snapshot: @Sendable () async -> [String: Int]
  /// foreground push 도착. 동일 notificationID 중복 호출은 skip. 알림 센터 entry 도 즉시 제거 시도.
  var increment: @Sendable (_ roomID: String, _ notificationID: String?) async -> Void
  /// 채팅방 진입. 해당 room 알림 센터 entry 일괄 제거 + dedup set 에서도 제거.
  var clear: @Sendable (_ roomID: String) async -> Void
  /// foreground 복귀. 알림 센터 entries 중 dedup set 에 없는 것만 흡수.
  var catchUp: @Sendable () async -> Void
  /// 로그아웃/세션 만료. 모든 카운트 + dedup set + 알림 센터 entry 제거.
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
