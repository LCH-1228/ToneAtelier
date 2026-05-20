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

  func testChatSocketConnectionBuilderSeparatesBaseURLAndNamespace() throws {
    let builder = ChatSocketConnectionBuilder()
    let configuration = APIConfiguration(
      baseURL: try XCTUnwrap(URL(string: "https://example.com/v1?foo=bar#frag")),
      seSACKey: "key"
    )

    let connection = try builder.build(roomID: "room-123", configuration: configuration)
    let components = try XCTUnwrap(
      URLComponents(url: connection.baseURL, resolvingAgainstBaseURL: false)
    )

    // baseURL은 path/query/fragment가 모두 비어 있어야 한다(SocketManager(socketURL:) 표준 입력).
    XCTAssertEqual(components.path, "")
    XCTAssertNil(components.query)
    XCTAssertNil(components.fragment)
    // namespace는 `/chats-{roomID}` 형태로 분리되어야 한다.
    XCTAssertEqual(connection.namespace, "/chats-room-123")
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

  func testMultipartFilenameEncodesNonASCIIAsASCIIFallback() throws {
    let formData = MultipartFormData(parts: [
      .file(UploadFile(
        fieldName: "files",
        fileName: "회의록.pdf",
        mimeType: "application/pdf",
        data: Data([0x25, 0x50, 0x44, 0x46])
      ))
    ])

    let endpoint = APIEndpoint<EmptyResponse>(
      method: .post,
      path: "/v1/test",
      body: .multipart(formData)
    )
    let session = SessionSnapshot.empty
    let request = try URLRequestBuilder().build(for: endpoint, session: session)
    let body = try XCTUnwrap(request.httpBody)
    let bodyString = try XCTUnwrap(String(data: body, encoding: .utf8))

    XCTAssertTrue(bodyString.contains("filename=\"___.pdf\""))
    XCTAssertFalse(bodyString.contains("filename*=UTF-8''"))
  }

  func testMultipartFilenamePreservesAsciiOriginal() throws {
    let formData = MultipartFormData(parts: [
      .file(UploadFile(
        fieldName: "files",
        fileName: "report.pdf",
        mimeType: "application/pdf",
        data: Data()
      ))
    ])

    let endpoint = APIEndpoint<EmptyResponse>(
      method: .post,
      path: "/v1/test",
      body: .multipart(formData)
    )
    let request = try URLRequestBuilder().build(for: endpoint, session: .empty)
    let body = try XCTUnwrap(request.httpBody)
    let bodyString = try XCTUnwrap(String(data: body, encoding: .utf8))

    XCTAssertTrue(bodyString.contains("filename=\"report.pdf\""))
  }
}
