//
//  JSONValueTests.swift
//  ToneAtelierTests
//
//  Created by Codex on 4/23/26.
//

import Foundation
import XCTest
@testable import ToneAtelier

@MainActor
final class JSONValueTests: XCTestCase {

  func testDecodesNestedJSON() throws {
    let data = Data(
      """
      {
        "name": "ToneAtelier",
        "version": 1,
        "enabled": true,
        "items": ["a", 2, false, null],
        "payload": {
          "nested": "value"
        }
      }
      """.utf8
    )

    let decoded = try JSONDecoder.api.decode(JSONValue.self, from: data)

    XCTAssertEqual(
      decoded,
      .object([
        "name": .string("ToneAtelier"),
        "version": .number(1),
        "enabled": .boolean(true),
        "items": .array([
          .string("a"),
          .number(2),
          .boolean(false),
          .null,
        ]),
        "payload": .object([
          "nested": .string("value")
        ]),
      ])
    )
  }

  func testRoundTripsThroughCodable() throws {
    let original = JSONValue.object([
      "message": .string("hello"),
      "count": .number(3),
      "flags": .array([.boolean(true), .boolean(false)]),
    ])

    let data = try JSONEncoder.api.encode(original)
    let decoded = try JSONDecoder.api.decode(JSONValue.self, from: data)

    XCTAssertEqual(decoded, original)
  }
}
