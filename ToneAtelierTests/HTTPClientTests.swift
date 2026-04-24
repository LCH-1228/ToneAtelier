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
      invalidateSession: {},
      loadSession: { session },
      refreshTokens: {
        TokenRefreshResponse(accessToken: "unused", refreshToken: "unused")
      },
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
      invalidateSession: {},
      loadSession: { session },
      refreshTokens: {
        TokenRefreshResponse(accessToken: "unused", refreshToken: "unused")
      },
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

  func testSendRetriesOriginalRequestAfter401WhenRefreshSucceeds() async throws {
    let recorder = TokenUpdateRecorder()
    let invalidationRecorder = SessionInvalidationRecorder()
    let session = makeSession()
    let unauthorizedResponse = try makeHTTPResponse(
      urlString: "https://example.com/posts",
      statusCode: 401
    )
    let successResponse = try makeHTTPResponse(
      urlString: "https://example.com/posts",
      statusCode: 200
    )
    let executeRecorder = RequestExecutionRecorder(
      results: [
        .success((
          try makeMessagePayload(message: "invalid token"),
          unauthorizedResponse
        )),
        .success((
          Data(),
          successResponse
        ))
      ]
    )

    let client = HTTPClient(
      execute: { _ in
        try await executeRecorder.next()
      },
      invalidateSession: {
        await invalidationRecorder.record()
      },
      loadSession: { session },
      refreshTokens: {
        TokenRefreshResponse(
          accessToken: "refreshed-access-token",
          refreshToken: "refreshed-refresh-token"
        )
      },
      updateTokens: { accessToken, refreshToken in
        await recorder.record(accessToken: accessToken, refreshToken: refreshToken)
      }
    )

    let endpoint = APIEndpoint<EmptyResponse>(
      method: .get,
      path: "/posts",
      requiresAccessToken: true
    )

    let result = try await client.send(endpoint)
    let executionCount = await executeRecorder.snapshotCount()
    let recorded = await recorder.snapshot()
    let invalidationCount = await invalidationRecorder.snapshot()

    XCTAssertEqual(result, EmptyResponse())
    XCTAssertEqual(executionCount, 2)
    XCTAssertEqual(
      recorded,
      TokenPair(
        accessToken: "refreshed-access-token",
        refreshToken: "refreshed-refresh-token"
      )
    )
    XCTAssertEqual(invalidationCount, 0)
  }

  func testSendInvalidatesSessionWhenRefreshFailsWithExpiredRefreshToken() async throws {
    let recorder = TokenUpdateRecorder()
    let invalidationRecorder = SessionInvalidationRecorder()
    let session = makeSession()
    let expiredPayload = try makeMessagePayload(message: "expired access token")
    let expiredResponse = try makeHTTPResponse(
      urlString: "https://example.com/posts",
      statusCode: 419
    )

    let client = HTTPClient(
      execute: { _ in
        (
          expiredPayload,
          expiredResponse
        )
      },
      invalidateSession: {
        await invalidationRecorder.record()
      },
      loadSession: { session },
      refreshTokens: {
        throw APIError.server(
          statusCode: 418,
          message: "expired refresh token",
          rawBody: nil
        )
      },
      updateTokens: { accessToken, refreshToken in
        await recorder.record(accessToken: accessToken, refreshToken: refreshToken)
      }
    )

    let endpoint = APIEndpoint<EmptyResponse>(
      method: .get,
      path: "/posts",
      requiresAccessToken: true
    )

    await XCTAssertAsyncThrowsError(
      try await client.send(endpoint)
    ) { error in
      XCTAssertEqual(error as? APIError, .invalidSession(statusCode: 418))
    }

    let recorded = await recorder.snapshot()
    let invalidationCount = await invalidationRecorder.snapshot()

    XCTAssertNil(recorded)
    XCTAssertEqual(invalidationCount, 1)
  }

  func testSendKeepsSessionWhenRefreshFailsWithTransportError() async throws {
    let invalidationRecorder = SessionInvalidationRecorder()
    let session = makeSession()
    let expiredPayload = try makeMessagePayload(message: "expired access token")
    let expiredResponse = try makeHTTPResponse(
      urlString: "https://example.com/posts",
      statusCode: 419
    )

    let client = HTTPClient(
      execute: { _ in
        (
          expiredPayload,
          expiredResponse
        )
      },
      invalidateSession: {
        await invalidationRecorder.record()
      },
      loadSession: { session },
      refreshTokens: {
        throw APIError.transport("network unavailable")
      },
      updateTokens: { _, _ in }
    )

    let endpoint = APIEndpoint<EmptyResponse>(
      method: .get,
      path: "/posts",
      requiresAccessToken: true
    )

    await XCTAssertAsyncThrowsError(
      try await client.send(endpoint)
    ) { error in
      XCTAssertEqual(error as? APIError, .transport("network unavailable"))
    }

    let invalidationCount = await invalidationRecorder.snapshot()
    XCTAssertEqual(invalidationCount, 0)
  }

  func testSendInvalidatesSessionImmediatelyWhenResponseIs418() async throws {
    let invalidationRecorder = SessionInvalidationRecorder()
    let session = makeSession()
    let expiredPayload = try makeMessagePayload(message: "expired refresh token")
    let expiredResponse = try makeHTTPResponse(
      urlString: "https://example.com/posts",
      statusCode: 418
    )

    let client = HTTPClient(
      execute: { _ in
        (
          expiredPayload,
          expiredResponse
        )
      },
      invalidateSession: {
        await invalidationRecorder.record()
      },
      loadSession: { session },
      refreshTokens: {
        XCTFail("418에서는 refresh를 시도하면 안 됩니다.")
        return TokenRefreshResponse(accessToken: "unused", refreshToken: "unused")
      },
      updateTokens: { _, _ in }
    )

    let endpoint = APIEndpoint<EmptyResponse>(
      method: .get,
      path: "/posts",
      requiresAccessToken: true
    )

    await XCTAssertAsyncThrowsError(
      try await client.send(endpoint)
    ) { error in
      XCTAssertEqual(error as? APIError, .invalidSession(statusCode: 418))
    }

    let invalidationCount = await invalidationRecorder.snapshot()
    XCTAssertEqual(invalidationCount, 1)
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

  private func makeHTTPResponse(urlString: String, statusCode: Int) throws -> HTTPURLResponse {
    try XCTUnwrap(
      HTTPURLResponse(
        url: XCTUnwrap(URL(string: urlString)),
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: nil
      )
    )
  }

  private func makeMessagePayload(message: String) throws -> Data {
    try JSONSerialization.data(
      withJSONObject: ["message": message]
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

private actor SessionInvalidationRecorder {
  private var count = 0

  func record() {
    count += 1
  }

  func snapshot() -> Int {
    count
  }
}

private actor RequestExecutionRecorder {
  private var currentIndex = 0
  private let results: [Result<(Data, HTTPURLResponse), Error>]

  init(results: [Result<(Data, HTTPURLResponse), Error>]) {
    self.results = results
  }

  func snapshotCount() -> Int {
    currentIndex
  }

  func next() throws -> (Data, HTTPURLResponse) {
    guard currentIndex < results.count else {
      throw APIError.transport("No more stubbed responses")
    }

    let result = results[currentIndex]
    currentIndex += 1
    return try result.get()
  }
}

private func XCTAssertAsyncThrowsError<T>(
  _ expression: @autoclosure () async throws -> T,
  _ errorHandler: (Error) -> Void,
  file: StaticString = #filePath,
  line: UInt = #line
) async {
  do {
    _ = try await expression()
    XCTFail("error가 발생해야 합니다.", file: file, line: line)
  } catch {
    errorHandler(error)
  }
}
