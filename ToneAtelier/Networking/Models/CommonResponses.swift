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
  let like_status: Bool
}

struct UploadedFilesResponse: nonisolated Decodable, Equatable, Sendable {
  let files: [String]
}

struct ProfileImageUploadResponse: nonisolated Decodable, Equatable, Sendable {
  let profileImage: String
}

struct TokenRefreshResponse: nonisolated Decodable, Equatable, Sendable {
  let accessToken: String
  let refreshToken: String
}

struct AuthenticatedUserResponse: nonisolated Decodable, Equatable, Sendable {
  let user_id: String
  let email: String
  let nick: String
  let profileImage: String?
  let accessToken: String
  let refreshToken: String
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
  let route_path: String
  let body: String
  let contentType: String
  let status_code: String
}
