//
//  ChatModels.swift
//  ToneAtelier
//
//  Created by LCH on 4/29/26.
//

import Foundation

struct ChatUserSummary: nonisolated Decodable, Equatable, Sendable {
  let user_id: String
  let nick: String
  let name: String?
  let introduction: String?
  let profileImage: String?
  let hashTags: [String]?
}

struct ChatMessage: nonisolated Decodable, Equatable, Sendable {
  let chat_id: String
  let room_id: String
  let content: String?
  let createdAt: String
  let updatedAt: String?
  let sender: ChatUserSummary
  let files: [String]?
}

struct ChatRoom: nonisolated Decodable, Equatable, Sendable {
  let room_id: String
  let createdAt: String
  let updatedAt: String
  let participants: [ChatUserSummary]
  let lastChat: ChatMessage?
}

struct ChatRoomListResponse: nonisolated Decodable, Equatable, Sendable {
  let data: [ChatRoom]
}

struct ChatMessageListResponse: nonisolated Decodable, Equatable, Sendable {
  let data: [ChatMessage]
}

struct MyProfileResponse: nonisolated Decodable, Equatable, Sendable {
  let user_id: String
  let email: String?
  let nick: String
  let name: String?
  let introduction: String?
  let profileImage: String?
  let phoneNum: String?
  let hashTags: [String]?
}

struct UserSearchResponse: nonisolated Decodable, Equatable, Sendable {
  let data: [ChatUserSummary]
}
