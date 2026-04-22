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
}

extension APIRouter {
  var queryItems: [URLQueryItem] { [] }
  var headers: [String: String] { [:] }
  var body: HTTPBody { .none }
  var requiresAccessToken: Bool { false }
  var requiresRefreshToken: Bool { false }
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
      requiresRefreshToken: router.requiresRefreshToken
    )
  }
}

struct LikeStatusRequest: Encodable, Sendable {
  let like_status: Bool
}
