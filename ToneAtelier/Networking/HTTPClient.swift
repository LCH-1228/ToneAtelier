//
//  HTTPClient.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import Foundation

struct HTTPClient {
  var execute: @Sendable (_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
  var loadSession: @Sendable () async -> SessionSnapshot
  var updateTokens: @Sendable (_ accessToken: String?, _ refreshToken: String?) async -> Void
  var requestBuilder: URLRequestBuilder = URLRequestBuilder()

  func send<Response>(_ endpoint: APIEndpoint<Response>) async throws -> Response {
    let session = await loadSession()
    let request = try requestBuilder.build(for: endpoint, session: session)

    let data: Data
    let response: HTTPURLResponse

    do {
      (data, response) = try await execute(request)
    } catch {
      throw APIError.transport(error.localizedDescription)
    }

    dump(request)
    if let tokens = extractTokens(from: data) {
      await updateTokens(tokens.accessToken, tokens.refreshToken)
      print("여긴안됨")
    }

    guard (200..<300).contains(response.statusCode) else {
      throw makeServerError(statusCode: response.statusCode, data: data)
    }

    return try endpoint.parse(data, response, .api)
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
}

struct TokenPair: Equatable, Sendable {
  let accessToken: String?
  let refreshToken: String?
}

extension HTTPClient {
  static let live = HTTPClient(
    execute: { request in
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let response = response as? HTTPURLResponse else {
        throw APIError.transport("HTTPURLResponse를 받지 못했습니다.")
      }
      return (data, response)
    },
    loadSession: {
      await LiveNetworkSessionStorage.storage.snapshot()
    },
    updateTokens: { accessToken, refreshToken in
      await LiveNetworkSessionStorage.storage.updateTokens(
        accessToken: accessToken,
        refreshToken: refreshToken
      )
    }
  )
}
