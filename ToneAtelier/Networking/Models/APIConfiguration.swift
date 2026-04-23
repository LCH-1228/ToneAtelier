//
//  APIConfiguration.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import Foundation

struct APIConfiguration: Equatable, Sendable {
  var baseURL: URL
  var seSACKey: String

  static let `default` = APIConfiguration(
    baseURL: APIInfo.baseURL,
    seSACKey: APIInfo.key
  )
}

struct SessionSnapshot: Equatable, Sendable {
  var configuration: APIConfiguration
  var accessToken: String
  var refreshToken: String
  
  static let `default` = SessionSnapshot(
    configuration: .default,
    accessToken: APIInfo.accessToken,
    refreshToken: APIInfo.refreshToken
  )
}

extension String {
  var trimmed: String {
    trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
