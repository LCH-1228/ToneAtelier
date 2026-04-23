//
//  HTTPClientTests.swift
//  ToneAtelierTests
//
//  Created by Codex on 4/23/26.
//

import Foundation
import XCTest
@testable import ToneAtelier

@MainActor
final class HTTPClientTests: XCTestCase {

  func testSendUpdatesTokensAfterSuccessfulResponse() async throws {
    let recorder = TokenUpdateRecorder()
    let session = makeSession()
    let data = try makeTokenPayload(
      accessToken: "new-access-token",
      refreshToken: "new-refresh-token"
    )
    let url = try XCTUnwrap(URL(string: "https://example.com/auth/refresh"))
    let response = try XCTUnwrap(
      HTTPURLResponse(
        url: url,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
      )
    )

    let client = HTTPClient(
      execute: { _ in
        (
          data,
          response
        )
      },
      loadSession: { session },
      updateTokens: { accessToken, refreshToken in
        await recorder.record(accessToken: accessToken, refreshToken: refreshToken)
      }
    )

    let endpoint = APIEndpoint<EmptyResponse>(method: .get, path: "/auth/refresh")
    let result = try await client.send(endpoint)
    let recorded = await recorder.snapshot()

    XCTAssertEqual(result, EmptyResponse())
    XCTAssertEqual(
      recorded,
      TokenPair(accessToken: "new-access-token", refreshToken: "new-refresh-token")
    )
  }

  func testSendDoesNotUpdateTokensWhenResponseStatusIsFailure() async throws {
    let recorder = TokenUpdateRecorder()
    let session = makeSession()
    let data = try makeTokenPayload(
      accessToken: "should-not-save-access-token",
      refreshToken: "should-not-save-refresh-token",
      message: "unauthorized"
    )
    let url = try XCTUnwrap(URL(string: "https://example.com/auth/refresh"))
    let response = try XCTUnwrap(
      HTTPURLResponse(
        url: url,
        statusCode: 401,
        httpVersion: nil,
        headerFields: nil
      )
    )

    let client = HTTPClient(
      execute: { _ in
        (
          data,
          response
        )
      },
      loadSession: { session },
      updateTokens: { accessToken, refreshToken in
        await recorder.record(accessToken: accessToken, refreshToken: refreshToken)
      }
    )

    let endpoint = APIEndpoint<EmptyResponse>(method: .get, path: "/auth/refresh")

    do {
      _ = try await client.send(endpoint)
      XCTFail("server error가 발생해야 합니다.")
    } catch let error as APIError {
      XCTAssertEqual(
        error,
        .server(statusCode: 401, message: "unauthorized", rawBody: String(data: data, encoding: .utf8))
      )
    }

    let recorded = await recorder.snapshot()
    XCTAssertNil(recorded)
  }

  private func makeSession() -> SessionSnapshot {
    SessionSnapshot(
      configuration: APIConfiguration(
        baseURL: URL(string: "https://example.com")!,
        seSACKey: "sesac-key"
      ),
      accessToken: "current-access-token",
      refreshToken: "current-refresh-token"
    )
  }

  private func makeTokenPayload(
    accessToken: String,
    refreshToken: String,
    message: String? = nil
  ) throws -> Data {
    var payload: [String: Any] = [
      APIInfo.ResponseKey.accessToken: accessToken,
      APIInfo.ResponseKey.refreshToken: refreshToken,
    ]

    if let message {
      payload["message"] = message
    }

    return try JSONSerialization.data(withJSONObject: payload)
  }
}

private actor TokenUpdateRecorder {
  private var tokenPair: TokenPair?

  func record(accessToken: String?, refreshToken: String?) {
    tokenPair = TokenPair(accessToken: accessToken, refreshToken: refreshToken)
  }

  func snapshot() -> TokenPair? {
    tokenPair
  }
}
