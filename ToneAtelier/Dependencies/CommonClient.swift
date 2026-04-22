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
}

extension CommonClient: DependencyKey {
  static var liveValue: CommonClient {
    @Dependency(\.httpClient) var httpClient

    return CommonClient(
      fetchLogs: {
        try await httpClient.send(
          APIEndpoint<LogsResponse>(router: CommonRouter.fetchLogs)
        )
      }
    )
  }

  static let testValue = CommonClient(
    fetchLogs: {
      throw APIError.transport("CommonClient.fetchLogs testValue")
    }
  )
}

extension DependencyValues {
  var commonClient: CommonClient {
    get { self[CommonClient.self] }
    set { self[CommonClient.self] = newValue }
  }
}
