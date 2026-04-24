//
//  HTTPClient.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import Foundation

struct HTTPClient {
  var execute: @Sendable (_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
  var invalidateSession: @Sendable () async -> Void
  var loadSession: @Sendable () async -> SessionSnapshot
  var refreshTokens: @Sendable () async throws -> TokenRefreshResponse
  var updateTokens: @Sendable (_ accessToken: String?, _ refreshToken: String?) async -> Void
  var requestBuilder: URLRequestBuilder = URLRequestBuilder()

  func send<Response>(_ endpoint: APIEndpoint<Response>) async throws -> Response {
    try await send(endpoint, allowsTokenRefresh: true)
  }

  private func send<Response>(
    _ endpoint: APIEndpoint<Response>,
    allowsTokenRefresh: Bool
  ) async throws -> Response {
    let session = await loadSession()
    let request = try requestBuilder.build(for: endpoint, session: session)
    let (data, response) = try await performRequest(request)

    guard (200..<300).contains(response.statusCode) else {
      if shouldAttemptTokenRefresh(
        for: response.statusCode,
        endpoint: endpoint,
        allowsTokenRefresh: allowsTokenRefresh
      ) {
        return try await retryAfterRefreshingToken(endpoint)
      }

      if shouldInvalidateSession(
        for: response.statusCode,
        endpoint: endpoint,
        allowsTokenRefresh: allowsTokenRefresh
      ) {
        await invalidateSession()
        throw APIError.invalidSession(statusCode: response.statusCode)
      }

      throw makeServerError(statusCode: response.statusCode, data: data)
    }

    if let tokens = extractTokens(from: data) {
      await updateTokens(tokens.accessToken, tokens.refreshToken)
    }

    return try endpoint.parse(data, response, .api)
  }

  private func performRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    do {
      return try await execute(request)
    } catch {
      throw APIError.transport(error.localizedDescription)
    }
  }

  private func retryAfterRefreshingToken<Response>(
    _ endpoint: APIEndpoint<Response>
  ) async throws -> Response {
    do {
      let refreshResponse = try await refreshTokens()
      await updateTokens(refreshResponse.accessToken, refreshResponse.refreshToken)
      return try await send(endpoint, allowsTokenRefresh: false)
    } catch {
      if shouldInvalidateSession(afterRefreshFailure: error) {
        await invalidateSession()
        throw invalidSessionError(from: error)
      }

      throw error
    }
  }

  private func makeServerError(statusCode: Int, data: Data) -> APIError {
    let rawBody = String(data: data, encoding: .utf8)

    if let message = try? JSONDecoder.api.decode(MessageResponse.self, from: data).message {
      return .server(statusCode: statusCode, message: message, rawBody: rawBody)
    }

    return .server(statusCode: statusCode, message: nil, rawBody: rawBody)
  }

  private func extractTokens(from data: Data) -> TokenPair? {
    guard let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return nil
    }

    let accessToken = payload[APIInfo.ResponseKey.accessToken] as? String
    let refreshToken = payload[APIInfo.ResponseKey.refreshToken] as? String

    guard accessToken != nil || refreshToken != nil else { return nil }
    return TokenPair(accessToken: accessToken, refreshToken: refreshToken)
  }

  private func invalidSessionError(from error: Error) -> APIError {
    guard let apiError = error as? APIError else {
      return .invalidSession(statusCode: 0)
    }

    switch apiError {
    case let .invalidSession(statusCode):
      return .invalidSession(statusCode: statusCode)
    case let .server(statusCode, _, _):
      return .invalidSession(statusCode: statusCode)
    case .missingAccessToken:
      return .invalidSession(statusCode: 401)
    case .missingRefreshToken:
      return .invalidSession(statusCode: 418)
    default:
      return .invalidSession(statusCode: 0)
    }
  }

  private func shouldAttemptTokenRefresh<Response>(
    for statusCode: Int,
    endpoint: APIEndpoint<Response>,
    allowsTokenRefresh: Bool
  ) -> Bool {
    allowsTokenRefresh
      && endpoint.requiresAccessToken
      && !endpoint.requiresRefreshToken
      && [401, 419].contains(statusCode)
  }

  private func shouldInvalidateSession<Response>(
    for statusCode: Int,
    endpoint: APIEndpoint<Response>,
    allowsTokenRefresh: Bool
  ) -> Bool {
    guard endpoint.requiresAccessToken else { return false }

    if statusCode == 418 {
      return true
    }

    return !allowsTokenRefresh && [401, 419].contains(statusCode)
  }

  private func shouldInvalidateSession(afterRefreshFailure error: Error) -> Bool {
    guard let apiError = error as? APIError else { return false }

    switch apiError {
    case .missingAccessToken, .missingRefreshToken:
      return true
    case let .server(statusCode, _, _):
      return [401, 418, 419].contains(statusCode)
    case let .invalidSession(statusCode):
      return [401, 418, 419].contains(statusCode)
    default:
      return false
    }
  }
}

struct TokenPair: Equatable, Sendable {
  let accessToken: String?
  let refreshToken: String?
}

extension HTTPClient {
  static let live: HTTPClient = {
    let storage = LiveSessionCenter.shared
    let requestBuilder = URLRequestBuilder()

    return HTTPClient(
      execute: { request in
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
          throw APIError.transport("HTTPURLResponse를 받지 못했습니다.")
        }
        return (data, response)
      },
      invalidateSession: {
        await storage.invalidateSession()
      },
      loadSession: {
        await storage.snapshot()
      },
      refreshTokens: {
        let session = await storage.snapshot()
        let endpoint = try await MainActor.run {
          try APIEndpoint<TokenRefreshResponse>(router: AuthRouter.refresh)
        }
        let request = try await MainActor.run {
          try requestBuilder.build(for: endpoint, session: session)
        }

        let data: Data
        let response: HTTPURLResponse

        do {
          let result = try await URLSession.shared.data(for: request)
          guard let httpResponse = result.1 as? HTTPURLResponse else {
            throw APIError.transport("HTTPURLResponse를 받지 못했습니다.")
          }

          data = result.0
          response = httpResponse
        } catch {
          throw APIError.transport(error.localizedDescription)
        }

        guard (200..<300).contains(response.statusCode) else {
          let rawBody = String(data: data, encoding: .utf8)
          let message = try? await MainActor.run {
            try JSONDecoder.api.decode(MessageResponse.self, from: data).message
          }

          if let message {
            throw APIError.server(statusCode: response.statusCode, message: message, rawBody: rawBody)
          }

          throw APIError.server(statusCode: response.statusCode, message: nil, rawBody: rawBody)
        }

        return try await MainActor.run {
          try endpoint.parse(data, response, .api)
        }
      },
      updateTokens: { accessToken, refreshToken in
        await storage.updateTokens(
          accessToken: accessToken,
          refreshToken: refreshToken
        )
      },
      requestBuilder: requestBuilder
    )
  }()
}
