//
//  AuthClient.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import ComposableArchitecture
import Foundation

struct AuthClient {
  var refresh: @Sendable () async throws -> TokenRefreshResponse
}

extension AuthClient: DependencyKey {
  static var liveValue: AuthClient {
    @Dependency(\.httpClient) var httpClient

    return AuthClient(
      refresh: {
        try await httpClient.send(
          APIEndpoint<TokenRefreshResponse>(router: AuthRouter.refresh)
        )
      }
    )
  }

  static let testValue = AuthClient(
    refresh: {
      throw APIError.transport("AuthClient.refresh testValue")
    }
  )
}

extension DependencyValues {
  var authClient: AuthClient {
    get { self[AuthClient.self] }
    set { self[AuthClient.self] = newValue }
  }
}
