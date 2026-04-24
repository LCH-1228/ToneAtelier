//
//  LiveSessionCenterTests.swift
//  ToneAtelierTests
//
//  Created by Codex on 4/24/26.
//

import XCTest
@testable import ToneAtelier

@MainActor
final class LiveSessionCenterTests: XCTestCase {

  func testRefreshTokensCoalescesConcurrentRequests() async throws {
    let store = makeStore()
    let center = LiveSessionCenter(store: store)
    let operationRecorder = RefreshOperationRecorder(
      result: TokenRefreshResponse(
        accessToken: "refreshed-access-token",
        refreshToken: "refreshed-refresh-token"
      )
    )

    async let first = center.refreshTokens {
      try await operationRecorder.execute()
    }
    async let second = center.refreshTokens {
      try await operationRecorder.execute()
    }

    let firstResult = try await first
    let secondResult = try await second
    let invocationCount = await operationRecorder.snapshotCount()
    let snapshot = await store.snapshot()

    XCTAssertEqual(firstResult, secondResult)
    XCTAssertEqual(invocationCount, 1)
    XCTAssertEqual(snapshot.accessToken, "refreshed-access-token")
    XCTAssertEqual(snapshot.refreshToken, "refreshed-refresh-token")
  }

  private func makeStore() -> KeychainSessionStore {
    let service = "ToneAtelierTests.refresh.\(UUID().uuidString)"
    let store = KeychainSessionStore(service: service)

    addTeardownBlock {
      Task {
        await store.clearTokens()
      }
    }

    return store
  }
}

private actor RefreshOperationRecorder {
  private let result: TokenRefreshResponse
  private var invocationCount = 0

  init(result: TokenRefreshResponse) {
    self.result = result
  }

  func execute() async throws -> TokenRefreshResponse {
    invocationCount += 1
    try await Task.sleep(nanoseconds: 50_000_000)
    return result
  }

  func snapshotCount() -> Int {
    invocationCount
  }
}
