//
//  APITestSupportTests.swift
//  ToneAtelierTests
//
//  Created by Codex on 4/23/26.
//

import XCTest
@testable import ToneAtelier

@MainActor
final class APITestSupportTests: XCTestCase {

  func testOptionalStringTrimsWhitespace() {
    XCTAssertEqual(optionalString("  hello  "), "hello")
    XCTAssertNil(optionalString("   \n\t "))
  }

  func testCSVValuesSplitsAndTrims() {
    XCTAssertEqual(csvValues("a, b , , c"), ["a", "b", "c"])
    XCTAssertNil(csvValues("   "))
  }

  func testNumericParsersValidateInputs() throws {
    XCTAssertEqual(try optionalInt("42", field: "limit"), 42)
    XCTAssertEqual(try XCTUnwrap(optionalDouble("3.14", field: "latitude")), 3.14, accuracy: 0.0001)
    XCTAssertNil(try optionalInt("   ", field: "limit"))

    XCTAssertThrowsError(try optionalInt("forty-two", field: "limit")) { error in
      XCTAssertAPITestInputError(error, matches: .invalidInt("limit"))
    }

    XCTAssertThrowsError(try optionalDouble("north", field: "latitude")) { error in
      XCTAssertAPITestInputError(error, matches: .invalidDouble("latitude"))
    }
  }

  func testJSONInputParserBuildsJSONValue() throws {
    let parsed = try optionalJSONValue(
      """
      {
        "title": "hello",
        "enabled": true,
        "count": 2,
        "tags": ["swift", null]
      }
      """,
      field: "payload"
    )
    let value = try XCTUnwrap(parsed)

    XCTAssertEqual(
      value,
      .object([
        "title": .string("hello"),
        "enabled": .boolean(true),
        "count": .number(2),
        "tags": .array([.string("swift"), .null]),
      ])
    )
  }

  func testJSONInputParserRejectsInvalidJSON() {
    XCTAssertThrowsError(try requiredJSONValue("{invalid", field: "payload")) { error in
      XCTAssertAPITestInputError(error, matches: .invalidJSON("payload"))
    }
  }

  func testSampleUploadFilesAreGenerated() {
    let files = sampleImageUploadFiles(prefix: "fixture", count: 2)

    XCTAssertEqual(files.count, 2)
    XCTAssertEqual(files[0].fileName, "fixture-1.png")
    XCTAssertEqual(files[1].fileName, "fixture-2.png")
    XCTAssertTrue(files.allSatisfy { $0.mimeType == "image/png" })
    XCTAssertTrue(files.allSatisfy { !$0.data.isEmpty })
  }
}

private func XCTAssertAPITestInputError(
  _ error: Error,
  matches expected: APITestInputError,
  file: StaticString = #filePath,
  line: UInt = #line
) {
  guard let actual = error as? APITestInputError else {
    XCTFail("APITestInputError가 아닙니다: \(error)", file: file, line: line)
    return
  }

  switch (actual, expected) {
  case let (.required(lhs), .required(rhs)),
       let (.invalidInt(lhs), .invalidInt(rhs)),
       let (.invalidDouble(lhs), .invalidDouble(rhs)),
       let (.invalidJSON(lhs), .invalidJSON(rhs)):
    XCTAssertEqual(lhs, rhs, file: file, line: line)
  default:
    XCTFail("예상한 에러와 다릅니다. actual: \(actual), expected: \(expected)", file: file, line: line)
  }
}
