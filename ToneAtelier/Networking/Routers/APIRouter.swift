//
//  APIRouter.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import Foundation

protocol APIRouter: Sendable {
  var method: HTTPMethod { get }
  var path: String { get }
  var queryItems: [URLQueryItem] { get }
  var headers: [String: String] { get }
  var body: HTTPBody { get throws }
  var requiresAccessToken: Bool { get }
  var requiresRefreshToken: Bool { get }
  /// true 인 경우 HTTPClient 가 200 응답 body 에서 access_token/refresh_token 키를 추출해 session 에 반영한다.
  /// login/join/refresh 등 토큰 발급 endpoint 전용. 일반 API 가 우연히 같은 키를 응답에 포함해 토큰을 덮어쓰는 사고를 막는다.
  var extractsTokensFromResponse: Bool { get }
}

extension APIRouter {
  var queryItems: [URLQueryItem] { [] }
  var headers: [String: String] { [:] }
  var body: HTTPBody { .none }
  var requiresAccessToken: Bool { false }
  var requiresRefreshToken: Bool { false }
  var extractsTokensFromResponse: Bool { false }
}

extension APIEndpoint where Response: Decodable {
  init(router: some APIRouter) throws {
    self.init(
      method: router.method,
      path: router.path,
      queryItems: router.queryItems,
      headers: router.headers,
      body: try router.body,
      requiresAccessToken: router.requiresAccessToken,
      requiresRefreshToken: router.requiresRefreshToken,
      extractsTokensFromResponse: router.extractsTokensFromResponse
    )
  }
}

struct LikeStatusRequest: Encodable, Sendable {
  let likeStatus: Bool

  enum CodingKeys: String, CodingKey {
    case likeStatus = "like_status"
  }
}
