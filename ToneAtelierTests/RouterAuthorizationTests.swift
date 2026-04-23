//
//  RouterAuthorizationTests.swift
//  ToneAtelierTests
//
//  Created by Codex on 4/23/26.
//

import Foundation
import XCTest
@testable import ToneAtelier

@MainActor
final class RouterAuthorizationTests: XCTestCase {

  func testAuthRefreshUsesAuthorizationAndRefreshTokenHeaders() throws {
    let endpoint = try APIEndpoint<EmptyResponse>(router: AuthRouter.refresh)
    let request = try URLRequestBuilder().build(for: endpoint, session: makeSession())

    XCTAssertEqual(
      request.value(forHTTPHeaderField: APIInfo.HeaderField.authorization),
      "access-token"
    )
    XCTAssertEqual(
      request.value(forHTTPHeaderField: APIInfo.HeaderField.refreshToken),
      "refresh-token"
    )
  }

  func testProtectedUserRouteUsesAuthorizationHeader() throws {
    let endpoint = try APIEndpoint<EmptyResponse>(router: UserRouter.fetchMyProfile)
    let request = try URLRequestBuilder().build(for: endpoint, session: makeSession())

    XCTAssertEqual(
      request.value(forHTTPHeaderField: APIInfo.HeaderField.authorization),
      "access-token"
    )
    XCTAssertNil(request.value(forHTTPHeaderField: APIInfo.HeaderField.refreshToken))
  }

  func testProtectedChatRouteRequiresAccessToken() throws {
    let router = ChatRouter.sendMessage(
      roomID: "room-123",
      SendChatRequest(content: "hello", files: nil)
    )
    let endpoint = try APIEndpoint<EmptyResponse>(router: router)

    XCTAssertThrowsError(
      try URLRequestBuilder().build(
        for: endpoint,
        session: makeSession(accessToken: "   ")
      )
    ) { error in
      XCTAssertEqual(error as? APIError, .missingAccessToken)
    }
  }

  private func makeSession(
    accessToken: String = "access-token",
    refreshToken: String = "refresh-token"
  ) -> SessionSnapshot {
    SessionSnapshot(
      configuration: APIConfiguration(
        baseURL: URL(string: "https://example.com")!,
        seSACKey: "sesac-key"
      ),
      accessToken: accessToken,
      refreshToken: refreshToken
    )
  }
}
