//
//  CommonResponses.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import Foundation

struct EmptyResponse: Decodable, Equatable, Sendable {}

struct MessageResponse: Decodable, Equatable, Sendable {
  let message: String
}

struct LikeStatusResponse: Decodable, Equatable, Sendable {
  let like_status: Bool
}

struct UploadedFilesResponse: Decodable, Equatable, Sendable {
  let files: [String]
}

struct ProfileImageUploadResponse: Decodable, Equatable, Sendable {
  let profileImage: String
}

struct TokenRefreshResponse: Decodable, Equatable, Sendable {
  let accessToken: String
  let refreshToken: String
}

struct AuthenticatedUserResponse: Decodable, Equatable, Sendable {
  let user_id: String
  let email: String
  let nick: String
  let profileImage: String?
  let accessToken: String
  let refreshToken: String
}

struct OrderCreatedResponse: Decodable, Equatable, Sendable {
  let order_id: String
  let order_code: String
  let total_price: Int
  let createdAt: String
  let updatedAt: String
}

struct LogsResponse: Decodable, Equatable, Sendable {
  let count: Int
  let logs: [LogEntry]
}

struct LogEntry: Decodable, Equatable, Sendable {
  let date: String
  let name: String
  let method: String
  let route_path: String
  let body: String
  let contentType: String
  let status_code: String
}
