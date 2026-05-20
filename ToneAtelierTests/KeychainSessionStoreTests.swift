//
//  KeychainSessionStoreTests.swift
//  ToneAtelierTests
//
//  Created by Codex on 4/24/26.
//

import XCTest
@testable import ToneAtelier

@MainActor
final class KeychainSessionStoreTests: XCTestCase {

  func testSnapshotReturnsEmptyTokensWhenNothingStored() async {
    let store = makeStore()

    let snapshot = await store.snapshot()
    let accessToken = snapshot.accessToken
    let refreshToken = snapshot.refreshToken

    XCTAssertEqual(accessToken, "")
    XCTAssertEqual(refreshToken, "")
  }

  func testUpdateTokensPersistsStoredValues() async {
    let store = makeStore()

    await store.updateTokens(
      accessToken: "access-token",
      refreshToken: "refresh-token"
    )

    let snapshot = await store.snapshot()
    let accessToken = snapshot.accessToken
    let refreshToken = snapshot.refreshToken

    XCTAssertEqual(accessToken, "access-token")
    XCTAssertEqual(refreshToken, "refresh-token")
  }

  func testClearTokensRemovesStoredValues() async {
    let store = makeStore()

    await store.updateTokens(
      accessToken: "access-token",
      refreshToken: "refresh-token"
    )

    await store.clearTokens()
    let snapshot = await store.snapshot()
    let accessToken = snapshot.accessToken
    let refreshToken = snapshot.refreshToken

    XCTAssertEqual(accessToken, "")
    XCTAssertEqual(refreshToken, "")
  }

  func testUpdateTokensWithNilKeepsExistingStoredValues() async {
    let store = makeStore()

    await store.updateTokens(
      accessToken: "access-token",
      refreshToken: "refresh-token"
    )
    await store.updateTokens(
      accessToken: nil,
      refreshToken: nil
    )

    let snapshot = await store.snapshot()
    let accessToken = snapshot.accessToken
    let refreshToken = snapshot.refreshToken

    XCTAssertEqual(accessToken, "access-token")
    XCTAssertEqual(refreshToken, "refresh-token")
  }

  private func makeStore() -> KeychainSessionStore {
    let service = "ToneAtelierTests.session.\(UUID().uuidString)"
    let store = KeychainSessionStore(service: service)

    addTeardownBlock {
      Task {
        await store.clearTokens()
      }
    }

    return store
  }
}
