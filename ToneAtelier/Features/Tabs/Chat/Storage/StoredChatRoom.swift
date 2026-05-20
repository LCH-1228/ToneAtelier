//
//  StoredChatRoom.swift
//  ToneAtelier
//
//  Created by LCH on 4/29/26.
//

import Foundation
import SwiftData

/// SwiftData 채팅방 엔티티.
/// `participants`는 Codable 배열 그대로 저장하고(@Relationship 대신 단순화),
/// 미리보기에 필요한 lastChat 필드는 펼쳐서 둔다(쿼리/정렬 단순화 목적).
@Model
final class StoredChatRoom {
  @Attribute(.unique) var roomID: String
  var createdAt: Date
  var updatedAt: Date
  var participantsData: Data

  var lastChatID: String?
  var lastChatContent: String?
  var lastChatCreatedAt: Date?
  var lastChatSenderUserID: String?
  var lastChatHasFiles: Bool

  /// 클라이언트 측 미읽음 카운트. 서버 응답에 없는 필드라 apply 시 보존한다.
  /// 기본값 0으로 SwiftData lightweight migration 자동 처리.
  var unreadCount: Int = 0

  init(
    roomID: String,
    createdAt: Date,
    updatedAt: Date,
    participantsData: Data,
    lastChatID: String?,
    lastChatContent: String?,
    lastChatCreatedAt: Date?,
    lastChatSenderUserID: String?,
    lastChatHasFiles: Bool,
    unreadCount: Int = 0
  ) {
    self.roomID = roomID
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.participantsData = participantsData
    self.lastChatID = lastChatID
    self.lastChatContent = lastChatContent
    self.lastChatCreatedAt = lastChatCreatedAt
    self.lastChatSenderUserID = lastChatSenderUserID
    self.lastChatHasFiles = lastChatHasFiles
    self.unreadCount = unreadCount
  }
}

/// 채팅방 엔티티 변환에 사용하는 정적 JSON 코더.
/// JSONEncoder/JSONDecoder는 thread-safe이므로 매 호출 새 인스턴스를 생성하지 않는다.
private enum JSONCoders {
  static let encoder = JSONEncoder()
  static let decoder = JSONDecoder()
}

extension StoredChatRoom {
  /// `ChatRoom` 응답을 SwiftData 엔티티로 변환.
  /// participants 인코딩 실패는 디코딩 에러로 propagate된다.
  static func make(from room: ChatRoom) throws -> StoredChatRoom {
    let participantsData = try JSONCoders.encoder.encode(room.participants)
    return StoredChatRoom(
      roomID: room.roomID,
      createdAt: ChatDateUtilities.parseISO8601(room.createdAt),
      updatedAt: ChatDateUtilities.parseISO8601(room.updatedAt),
      participantsData: participantsData,
      lastChatID: room.lastChat?.chatID,
      lastChatContent: room.lastChat?.content,
      lastChatCreatedAt: ChatDateUtilities.parseISO8601Optional(room.lastChat?.createdAt),
      lastChatSenderUserID: room.lastChat?.sender.userID,
      lastChatHasFiles: (room.lastChat?.files?.isEmpty == false)
    )
  }

  /// 기존 인스턴스의 필드를 새 응답으로 덮어쓰기 (upsert update 분기).
  func apply(_ room: ChatRoom) throws {
    let participantsData = try JSONCoders.encoder.encode(room.participants)
    self.createdAt = ChatDateUtilities.parseISO8601(room.createdAt)
    self.updatedAt = ChatDateUtilities.parseISO8601(room.updatedAt)
    self.participantsData = participantsData
    self.lastChatID = room.lastChat?.chatID
    self.lastChatContent = room.lastChat?.content
    self.lastChatCreatedAt = ChatDateUtilities.parseISO8601Optional(room.lastChat?.createdAt)
    self.lastChatSenderUserID = room.lastChat?.sender.userID
    self.lastChatHasFiles = (room.lastChat?.files?.isEmpty == false)
  }

  /// 저장된 participants 데이터를 디코딩한다.
  func participantsValue() throws -> [ChatUserSummary] {
    try JSONCoders.decoder.decode([ChatUserSummary].self, from: participantsData)
  }

  /// SwiftData 엔티티를 List 표시용 `ChatRoom`으로 매핑한다.
  /// lastChat의 sender는 participants에서 user_id로 조회해 조립한다.
  /// sender를 찾지 못하면 lastChat을 nil로 떨어뜨려 정합성을 유지한다.
  func asChatRoom() throws -> ChatRoom {
    let participants = try participantsValue()
    let lastChat: ChatMessage? = {
      guard
        let lastChatID,
        let lastChatCreatedAt,
        let lastChatSenderUserID,
        let sender = participants.first(where: { $0.userID == lastChatSenderUserID })
      else { return nil }

      return ChatMessage(
        chatID: lastChatID,
        roomID: roomID,
        content: lastChatContent,
        createdAt: ChatDateUtilities.formatISO8601(lastChatCreatedAt),
        updatedAt: nil,
        sender: sender,
        files: lastChatHasFiles ? [] : nil // 캐시 단계에서는 실제 URL을 보존하지 않으므로 placeholder
      )
    }()

    return ChatRoom(
      roomID: roomID,
      createdAt: ChatDateUtilities.formatISO8601(createdAt),
      updatedAt: ChatDateUtilities.formatISO8601(updatedAt),
      participants: participants,
      lastChat: lastChat
    )
  }
}
