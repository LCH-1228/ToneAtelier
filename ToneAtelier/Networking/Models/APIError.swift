//
//  APIError.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import Foundation

enum APIError: Error, Equatable, LocalizedError, Sendable {
  case invalidBaseURL(String)
  case invalidURL(String)
  case missingAccessToken
  case missingRefreshToken
  case transport(String)
  case server(statusCode: Int, message: String?, rawBody: String?)
  case decoding(String)

  var errorDescription: String? {
    switch self {
    case let .invalidBaseURL(value):
      return "Base URL이 올바르지 않습니다: \(value)"
    case let .invalidURL(path):
      return "URL을 만들 수 없습니다: \(path)"
    case .missingAccessToken:
      return "AccessToken이 필요한 요청입니다."
    case .missingRefreshToken:
      return "RefreshToken이 필요한 요청입니다."
    case let .transport(message):
      return "네트워크 전송 오류: \(message)"
    case let .server(statusCode, message, _):
      if let message, !message.isEmpty {
        return "서버 오류(\(statusCode)): \(message)"
      }
      return "서버 오류(\(statusCode))"
    case let .decoding(message):
      return "응답 디코딩 오류: \(message)"
    }
  }
}
