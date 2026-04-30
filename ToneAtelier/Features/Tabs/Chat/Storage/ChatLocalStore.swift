//
//  ChatLocalStore.swift
//  ToneAtelier
//
//  Created by LCH on 4/29/26.
//

import ComposableArchitecture
import Foundation
import OSLog
import SwiftData

// MARK: - ModelActor

/// 채팅 로컬 저장소 actor.
/// `@ModelActor`가 ModelContext를 actor 격리해 race-free 보장한다.
/// SwiftData 엔티티(`PersistentModel`)를 actor 외부로 누출시키지 않기 위해
/// 모든 공개 함수는 값 타입(`ChatRoom`/`ChatMessage`/`Date`/`String`) 또는
/// Void만 반환한다.
@ModelActor
actor ChatLocalStore {
  // MARK: - Rooms

  /// 응답으로 받은 채팅방 목록을 upsert한다.
  /// `@Attribute(.unique)`만으로는 자동 upsert가 보장되지 않아 fetch → 분기.
  func upsertRooms(_ rooms: [ChatRoom]) throws {
    for room in rooms {
      let targetRoomID = room.room_id
      var descriptor = FetchDescriptor<StoredChatRoom>(
        predicate: #Predicate { $0.roomID == targetRoomID }
      )
      descriptor.fetchLimit = 1

      if let existing = try modelContext.fetch(descriptor).first {
        try existing.apply(room)
      } else {
        let entity = try StoredChatRoom.make(from: room)
        modelContext.insert(entity)
      }
    }
    try modelContext.save()
  }

  /// 캐시된 채팅방 목록을 `updatedAt` 내림차순으로 반환한다.
  /// actor 내부에서 값 타입(`ChatRoom`)으로 변환한 뒤 반환해 누출을 막는다.
  func loadRoomsAsChatRooms() throws -> [ChatRoom] {
    let descriptor = FetchDescriptor<StoredChatRoom>(
      sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
    )
    let stored = try modelContext.fetch(descriptor)
    return try stored.map { try $0.asChatRoom() }
  }

  /// 모든 채팅방/메시지 캐시를 삭제한다 (로그아웃 시).
  func clearAll() throws {
    try modelContext.delete(model: StoredChatRoom.self)
    try modelContext.delete(model: StoredChatMessage.self)
    try modelContext.save()
  }

  // MARK: - Messages

  /// 메시지 배열을 upsert한다.
  func upsertMessages(_ messages: [ChatMessage], roomID: String) throws {
    for message in messages {
      let targetChatID = message.chat_id
      var descriptor = FetchDescriptor<StoredChatMessage>(
        predicate: #Predicate { $0.chatID == targetChatID }
      )
      descriptor.fetchLimit = 1

      if let existing = try modelContext.fetch(descriptor).first {
        try existing.apply(message)
      } else {
        let entity = try StoredChatMessage.make(from: message)
        modelContext.insert(entity)
      }
    }
    try modelContext.save()
  }

  /// 특정 방의 메시지를 `createdAt` 오름차순으로 반환한다.
  func loadMessagesAsChatMessages(roomID: String) throws -> [ChatMessage] {
    let targetRoomID = roomID
    let descriptor = FetchDescriptor<StoredChatMessage>(
      predicate: #Predicate { $0.roomID == targetRoomID },
      sortBy: [SortDescriptor(\.createdAt, order: .forward)]
    )
    let stored = try modelContext.fetch(descriptor)
    return try stored.map { try $0.asChatMessage() }
  }

  /// 특정 방의 가장 최근 메시지 시간을 ISO8601 문자열로 반환한다.
  /// 단계 3에서 `next` 쿼리 파라미터에 사용한다.
  func latestCreatedAtISO8601(roomID: String) throws -> String? {
    let targetRoomID = roomID
    var descriptor = FetchDescriptor<StoredChatMessage>(
      predicate: #Predicate { $0.roomID == targetRoomID },
      sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
    )
    descriptor.fetchLimit = 1
    guard let latest = try modelContext.fetch(descriptor).first else {
      return nil
    }
    return ChatDateUtilities.formatISO8601(latest.createdAt)
  }

  /// 특정 방의 메시지를 모두 삭제한다.
  func deleteMessages(roomID: String) throws {
    let targetRoomID = roomID
    try modelContext.delete(
      model: StoredChatMessage.self,
      where: #Predicate { $0.roomID == targetRoomID }
    )
    try modelContext.save()
  }
}

// MARK: - Dependency Client

/// `ChatLocalStore`를 TCA `@Dependency`로 노출하는 thin wrapper.
struct ChatLocalStoreClient {
  var upsertRooms: @Sendable (_ rooms: [ChatRoom]) async throws -> Void
  var loadRooms: @Sendable () async throws -> [ChatRoom]
  var upsertMessages: @Sendable (_ messages: [ChatMessage], _ roomID: String) async throws -> Void
  var loadMessages: @Sendable (_ roomID: String) async throws -> [ChatMessage]
  var latestCreatedAtISO8601: @Sendable (_ roomID: String) async throws -> String?
  var deleteMessages: @Sendable (_ roomID: String) async throws -> Void
  var clearAll: @Sendable () async throws -> Void
}

extension ChatLocalStoreClient: DependencyKey {
  static var liveValue: ChatLocalStoreClient {
    let store = LiveChatLocalStoreFactory.shared.store
    return ChatLocalStoreClient(
      upsertRooms: { rooms in
        try await store.upsertRooms(rooms)
      },
      loadRooms: {
        try await store.loadRoomsAsChatRooms()
      },
      upsertMessages: { messages, roomID in
        try await store.upsertMessages(messages, roomID: roomID)
      },
      loadMessages: { roomID in
        try await store.loadMessagesAsChatMessages(roomID: roomID)
      },
      latestCreatedAtISO8601: { roomID in
        try await store.latestCreatedAtISO8601(roomID: roomID)
      },
      deleteMessages: { roomID in
        try await store.deleteMessages(roomID: roomID)
      },
      clearAll: {
        try await store.clearAll()
      }
    )
  }

  static let testValue = ChatLocalStoreClient(
    upsertRooms: { _ in throw APIError.transport("ChatLocalStoreClient.upsertRooms testValue") },
    loadRooms: { throw APIError.transport("ChatLocalStoreClient.loadRooms testValue") },
    upsertMessages: { _, _ in throw APIError.transport("ChatLocalStoreClient.upsertMessages testValue") },
    loadMessages: { _ in throw APIError.transport("ChatLocalStoreClient.loadMessages testValue") },
    latestCreatedAtISO8601: { _ in throw APIError.transport("ChatLocalStoreClient.latestCreatedAtISO8601 testValue") },
    deleteMessages: { _ in throw APIError.transport("ChatLocalStoreClient.deleteMessages testValue") },
    clearAll: { throw APIError.transport("ChatLocalStoreClient.clearAll testValue") }
  )
}

extension DependencyValues {
  var chatLocalStore: ChatLocalStoreClient {
    get { self[ChatLocalStoreClient.self] }
    set { self[ChatLocalStoreClient.self] = newValue }
  }
}

// MARK: - Live Container Factory

/// 앱 전역 단일 `ModelContainer`/`ChatLocalStore` 인스턴스를 보유한다.
/// SwiftData ModelContainer는 동일 스키마/설정에 대해 인스턴스를 1개로 유지하는 것이
/// 권장 패턴이며, 부트스트랩 실패는 회복 불가능 케이스이므로 `Logger.app.fault` 후
/// `fatalError`로 처리한다 (다른 Live* 클라이언트 — 예: KakaoSDK 초기화 — 와 동일 톤).
private final class LiveChatLocalStoreFactory: @unchecked Sendable {
  static let shared = LiveChatLocalStoreFactory()

  let store: ChatLocalStore

  private init() {
    do {
      let schema = Schema([
        StoredChatRoom.self,
        StoredChatMessage.self
      ])
      let configuration = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: false
      )
      let container = try ModelContainer(for: schema, configurations: configuration)
      self.store = ChatLocalStore(modelContainer: container)
    } catch {
      Logger.chatStorage.fault(
        "ChatLocalStore bootstrap failed: \(error.localizedDescription, privacy: .public)"
      )
      fatalError("ChatLocalStore bootstrap failed: \(error)")
    }
  }
}

extension Logger {
  /// 채팅 로컬 저장소 부트스트랩/장애 로깅 카테고리.
  fileprivate nonisolated static let chatStorage = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.mitti.ToneAtelier",
    category: "ChatStorage"
  )
}
