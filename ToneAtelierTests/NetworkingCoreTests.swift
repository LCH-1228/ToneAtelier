//
//  NetworkingCoreTests.swift
//  ToneAtelierTests
//
//  Created by Codex on 4/23/26.
//

import Foundation
import XCTest
@testable import ToneAtelier

@MainActor
final class NetworkingCoreTests: XCTestCase {

  func testQueryItemOptionalOmitsBlankStrings() {
    XCTAssertNil(URLQueryItem.optional(name: "nick", value: Optional<String>.none))
    XCTAssertNil(URLQueryItem.optional(name: "nick", value: "   "))
    XCTAssertEqual(
      URLQueryItem.optional(name: "nick", value: " sesac "),
      URLQueryItem(name: "nick", value: "sesac")
    )
  }

  func testQueryItemOptionalConvertsNumericValues() {
    XCTAssertEqual(
      URLQueryItem.optional(name: "limit", value: 10),
      URLQueryItem(name: "limit", value: "10")
    )
    XCTAssertNil(URLQueryItem.optional(name: "limit", value: Optional<Int>.none))
  }

  func testChatHistoryQueryBuildsExpectedItems() {
    XCTAssertTrue(ChatHistoryQuery(next: nil).queryItems.isEmpty)
    XCTAssertTrue(ChatHistoryQuery(next: "   ").queryItems.isEmpty)
    XCTAssertEqual(
      ChatHistoryQuery(next: "2026-04-23T00:00:00Z").queryItems,
      [URLQueryItem(name: "next", value: "2026-04-23T00:00:00Z")]
    )
  }

  func testFilterListQueryKeepsEmptyNextCursor() {
    XCTAssertEqual(
      FilterListQuery(next: "", limit: 5).queryItems,
      [
        URLQueryItem(name: "next", value: ""),
        URLQueryItem(name: "limit", value: "5"),
      ]
    )
  }

  func testChatSocketURLBuilderCreatesSocketURL() throws {
    let builder = ChatSocketURLBuilder()
    let configuration = APIConfiguration(
      baseURL: try XCTUnwrap(URL(string: "https://example.com/v1?foo=bar#frag")),
      seSACKey: "key"
    )

    let url = try builder.build(roomID: "room-123", configuration: configuration)
    let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))

    XCTAssertNil(components.query)
    XCTAssertNil(components.fragment)
    XCTAssertTrue(url.path.contains("room-123"))
  }

  func testEmptyResponseEndpointAcceptsEmptyBody() throws {
    let endpoint = APIEndpoint<EmptyResponse>(method: .get, path: "/test")
    let response = try makeHTTPResponse(urlString: "https://example.com/test")

    let result = try endpoint.parse(Data(), response, .api)

    XCTAssertEqual(result, EmptyResponse())
  }

  func testDecodableEndpointRejectsEmptyBody() throws {
    let endpoint = APIEndpoint<MessageResponse>(method: .get, path: "/test")
    let response = try makeHTTPResponse(urlString: "https://example.com/test")

    XCTAssertThrowsError(try endpoint.parse(Data(), response, .api)) { error in
      XCTAssertEqual(error as? APIError, .decoding("비어 있는 응답입니다."))
    }
  }

  private func makeHTTPResponse(urlString: String, statusCode: Int = 200) throws -> HTTPURLResponse {
    try XCTUnwrap(
      HTTPURLResponse(
        url: XCTUnwrap(URL(string: urlString)),
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: nil
      )
    )
  }
}
