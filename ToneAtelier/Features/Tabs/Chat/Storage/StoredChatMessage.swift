//
//  StoredChatMessage.swift
//  ToneAtelier
//
//  Created by LCH on 4/29/26.
//

import Foundation
import SwiftData

/// SwiftData 채팅 메시지 엔티티.
/// 단계 3에서 `loadMessages`/페이지네이션·신규 송수신 동기화에 사용된다.
@Model
final class StoredChatMessage {
  @Attribute(.unique) var chatID: String
  var roomID: String
  var content: String?
  var createdAt: Date
  var updatedAt: Date?
  var senderUserID: String
  var senderNick: String
  var senderName: String?
  var senderIntroduction: String?
  var senderProfileImage: String?
  var senderHashTagsData: Data?
  var filesData: Data

  init(
    chatID: String,
    roomID: String,
    content: String?,
    createdAt: Date,
    updatedAt: Date?,
    senderUserID: String,
    senderNick: String,
    senderName: String?,
    senderIntroduction: String?,
    senderProfileImage: String?,
    senderHashTagsData: Data?,
    filesData: Data
  ) {
    self.chatID = chatID
    self.roomID = roomID
    self.content = content
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.senderUserID = senderUserID
    self.senderNick = senderNick
    self.senderName = senderName
    self.senderIntroduction = senderIntroduction
    self.senderProfileImage = senderProfileImage
    self.senderHashTagsData = senderHashTagsData
    self.filesData = filesData
  }
}

/// 채팅 메시지 엔티티 변환에 사용하는 정적 JSON 코더.
/// JSONEncoder/JSONDecoder는 thread-safe이므로 매 호출 새 인스턴스를 생성하지 않는다.
private enum JSONCoders {
  static let encoder = JSONEncoder()
  static let decoder = JSONDecoder()
}

extension StoredChatMessage {
  static func make(from message: ChatMessage) throws -> StoredChatMessage {
    let filesData = try JSONCoders.encoder.encode(message.files ?? [])
    let hashTagsData: Data? = try {
      guard let tags = message.sender.hashTags else { return nil }
      return try JSONCoders.encoder.encode(tags)
    }()

    return StoredChatMessage(
      chatID: message.chat_id,
      roomID: message.room_id,
      content: message.content,
      createdAt: ChatDateUtilities.parseISO8601(message.createdAt),
      updatedAt: ChatDateUtilities.parseISO8601Optional(message.updatedAt),
      senderUserID: message.sender.user_id,
      senderNick: message.sender.nick,
      senderName: message.sender.name,
      senderIntroduction: message.sender.introduction,
      senderProfileImage: message.sender.profileImage,
      senderHashTagsData: hashTagsData,
      filesData: filesData
    )
  }

  func apply(_ message: ChatMessage) throws {
    let filesData = try JSONCoders.encoder.encode(message.files ?? [])
    let hashTagsData: Data? = try {
      guard let tags = message.sender.hashTags else { return nil }
      return try JSONCoders.encoder.encode(tags)
    }()

    self.roomID = message.room_id
    self.content = message.content
    self.createdAt = ChatDateUtilities.parseISO8601(message.createdAt)
    self.updatedAt = ChatDateUtilities.parseISO8601Optional(message.updatedAt)
    self.senderUserID = message.sender.user_id
    self.senderNick = message.sender.nick
    self.senderName = message.sender.name
    self.senderIntroduction = message.sender.introduction
    self.senderProfileImage = message.sender.profileImage
    self.senderHashTagsData = hashTagsData
    self.filesData = filesData
  }

  /// 파일 URL 배열을 디코딩한다 (실패 시 빈 배열).
  func filesValue() -> [String] {
    (try? JSONCoders.decoder.decode([String].self, from: filesData)) ?? []
  }

  /// SwiftData 엔티티를 `ChatMessage`로 매핑한다.
  func asChatMessage() throws -> ChatMessage {
    let files = filesValue()
    let hashTags: [String]? = {
      guard let senderHashTagsData else { return nil }
      return try? JSONCoders.decoder.decode([String].self, from: senderHashTagsData)
    }()
    let sender = ChatUserSummary(
      user_id: senderUserID,
      nick: senderNick,
      name: senderName,
      introduction: senderIntroduction,
      profileImage: senderProfileImage,
      hashTags: hashTags
    )

    return ChatMessage(
      chat_id: chatID,
      room_id: roomID,
      content: content,
      createdAt: ChatDateUtilities.formatISO8601(createdAt),
      updatedAt: updatedAt.map(ChatDateUtilities.formatISO8601),
      sender: sender,
      files: files.isEmpty ? nil : files
    )
  }
}
