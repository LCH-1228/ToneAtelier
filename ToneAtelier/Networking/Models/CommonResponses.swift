//
//  CommonResponses.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import Foundation

struct EmptyResponse: nonisolated Decodable, Equatable, Sendable {}

struct MessageResponse: nonisolated Decodable, Equatable, Sendable {
  let message: String
}

struct LikeStatusResponse: nonisolated Decodable, Equatable, Sendable {
  let likeStatus: Bool

  enum CodingKeys: String, CodingKey {
    case likeStatus = "like_status"
  }
}

struct UploadedFilesResponse: nonisolated Decodable, Equatable, Sendable {
  let files: [String]
}

/// spec FileResponseDTO/ChatFileResponseDTO/PostFileResponseDTO 모두 동일 스키마 alias.
typealias FileResponseDTO = UploadedFilesResponse
typealias ChatFileResponseDTO = UploadedFilesResponse
typealias PostFileResponseDTO = UploadedFilesResponse

struct ProfileImageUploadResponse: nonisolated Decodable, Equatable, Sendable {
  let profileImage: String
}

struct TokenRefreshResponse: nonisolated Decodable, Equatable, Sendable {
  let accessToken: String
  let refreshToken: String
}

struct AuthenticatedUserResponse: nonisolated Decodable, Equatable, Sendable {
  let userID: String
  let email: String
  let nick: String
  let profileImage: String?
  let accessToken: String
  let refreshToken: String

  enum CodingKeys: String, CodingKey {
    case userID = "user_id"
    case email, nick, profileImage, accessToken, refreshToken
  }
}

/// spec OrderCreateResponseDTO와 동일 스키마. 정식 타입은 CommerceClient.swift에 정의.
typealias OrderCreatedResponse = OrderCreateResponseDTO

struct LogsResponse: nonisolated Decodable, Equatable, Sendable {
  let count: Int
  let logs: [LogEntry]
}

struct LogEntry: nonisolated Decodable, Equatable, Sendable {
  let date: String
  let name: String
  let method: String
  let routePath: String
  let body: String
  let contentType: String
  let statusCode: String

  enum CodingKeys: String, CodingKey {
    case date, name, method
    case routePath = "route_path"
    case body, contentType
    case statusCode = "status_code"
  }
}
