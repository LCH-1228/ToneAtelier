//
//  CommonClient.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import ComposableArchitecture
import Foundation

struct CommonClient {
  var fetchLogs: @Sendable () async throws -> LogsResponse
  var fetchPhoto: @Sendable (_ path: String) async throws -> Data
}

extension CommonClient: DependencyKey {
  static var liveValue: CommonClient {
    @Dependency(\.httpClient) var httpClient

    return CommonClient(
      fetchLogs: {
        try await httpClient.send(
          APIEndpoint<LogsResponse>(router: CommonRouter.fetchLogs)
        )
      },
      fetchPhoto: { path in
        let router = CommonRouter.fetchPhoto(path)

        return try await httpClient.send(
          APIEndpoint<Data>(
            method: router.method,
            path: router.path,
            queryItems: router.queryItems,
            headers: router.headers,
            body: router.body,
            requiresAccessToken: router.requiresAccessToken,
            requiresRefreshToken: router.requiresRefreshToken
          ) { data, _, _ in
            data
          }
        )
      }
    )
  }

  static let testValue = CommonClient(
    fetchLogs: {
      throw APIError.transport("CommonClient.fetchLogs testValue")
    },
    fetchPhoto: { _ in
      throw APIError.transport("CommonClient.fetchPhoto testValue")
    }
  )
}

extension DependencyValues {
  var commonClient: CommonClient {
    get { self[CommonClient.self] }
    set { self[CommonClient.self] = newValue }
  }
}
