//
//  ChatResponseDTO.swift
//  ToneAtelier
//
//  Created by LCH on 4/29/26.
//

import Foundation

/// spec ChatResponseDTO. 채팅 메시지 단건.
struct ChatMessage: nonisolated Decodable, Equatable, Sendable {
  let chatID: String
  let roomID: String
  let content: String?
  let createdAt: String
  let updatedAt: String?
  let sender: UserInfoResponseDTO
  let files: [String]?

  enum CodingKeys: String, CodingKey {
    case chatID = "chat_id"
    case roomID = "room_id"
    case content, createdAt, updatedAt, sender, files
  }
}

/// spec ChatRoomResponseDTO. 채팅방 단건.
struct ChatRoom: nonisolated Decodable, Equatable, Sendable {
  let roomID: String
  let createdAt: String
  let updatedAt: String
  let participants: [UserInfoResponseDTO]
  let lastChat: ChatMessage?

  enum CodingKeys: String, CodingKey {
    case roomID = "room_id"
    case createdAt, updatedAt, participants, lastChat
  }
}

/// spec ChatRoomListResponseDTO.
struct ChatRoomListResponse: nonisolated Decodable, Equatable, Sendable {
  let data: [ChatRoom]
}

/// spec ChatListResponseDTO. 채팅 메시지 페이지.
struct ChatMessageListResponse: nonisolated Decodable, Equatable, Sendable {
  let data: [ChatMessage]
}

// MARK: - Spec name aliases

/// spec ChatResponseDTO와 동일 스키마.
typealias ChatResponseDTO = ChatMessage

/// spec ChatRoomResponseDTO와 동일 스키마.
typealias ChatRoomResponseDTO = ChatRoom

/// spec ChatRoomListResponseDTO와 동일 스키마.
typealias ChatRoomListResponseDTO = ChatRoomListResponse

/// spec ChatListResponseDTO와 동일 스키마.
typealias ChatListResponseDTO = ChatMessageListResponse
