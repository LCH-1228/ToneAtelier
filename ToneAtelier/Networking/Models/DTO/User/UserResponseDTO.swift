//
//  UserResponseDTO.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import Foundation

/// spec UserInfoResponseDTO. 다른 도메인이 creator/sender 등으로 참조하는 공용 사용자 정보.
/// 채팅방 storage에서 직렬화도 하므로 Codable로 채택.
struct UserInfoResponseDTO: nonisolated Codable, Equatable, Sendable {
  let userID: String
  let nick: String
  let name: String?
  let introduction: String?
  let profileImage: String?
  let hashTags: [String]?

  enum CodingKeys: String, CodingKey {
    case userID = "user_id"
    case nick, name, introduction, profileImage, hashTags
  }
}

/// spec MyInfoResponseDTO. 내 프로필 응답.
struct MyInfoResponseDTO: nonisolated Decodable, Equatable, Sendable {
  let userID: String
  let email: String?
  let nick: String
  let name: String?
  let introduction: String?
  let profileImage: String?
  let phoneNum: String?
  let hashTags: [String]?

  enum CodingKeys: String, CodingKey {
    case userID = "user_id"
    case email, nick, name, introduction, profileImage, phoneNum, hashTags
  }
}

/// spec TodayAuthorInfoResponseDTO. 오늘의 작가 응답에 사용되는 작가 본문.
struct TodayAuthorInfoResponseDTO: nonisolated Decodable, Equatable, Sendable {
  let userID: String
  let nick: String
  let name: String?
  let introduction: String?
  let description: String?
  let profileImage: String?
  let hashTags: [String]?

  enum CodingKeys: String, CodingKey {
    case userID = "user_id"
    case nick, name, introduction, description, profileImage, hashTags
  }
}

/// spec UserInfoListResponseDTO. /v1/users/search 등 사용자 목록.
struct UserInfoListResponseDTO: nonisolated Decodable, Equatable, Sendable {
  let data: [UserInfoResponseDTO]
}
