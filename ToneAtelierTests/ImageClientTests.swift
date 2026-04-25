//
//  ImageClientTests.swift
//  ToneAtelierTests
//
//  Created by Codex on 4/25/26.
//

import Foundation
import XCTest
@testable import ToneAtelier

actor ImageLoadCounter {
  private(set) var value = 0

  func increment() {
    value += 1
  }

  func current() -> Int {
    value
  }
}

@MainActor
final class ImageClientTests: XCTestCase {
  func testLiveImageStoreCachesLoadedData() async throws {
    let store = LiveImageStore()
    let counter = ImageLoadCounter()
    let expectedData = Data("image-data".utf8)

    let first = try await store.data(for: "/banner-1") {
      await counter.increment()
      return expectedData
    }

    let second = try await store.data(for: "/banner-1") {
      await counter.increment()
      return Data("different".utf8)
    }

    XCTAssertEqual(first, expectedData)
    XCTAssertEqual(second, expectedData)
    let count = await counter.current()
    XCTAssertEqual(count, 1)
  }

  func testLiveImageStoreJoinsInFlightTaskForSamePath() async throws {
    let store = LiveImageStore()
    let counter = ImageLoadCounter()
    let expectedData = Data("shared-image".utf8)

    async let first: Data = store.data(for: "/banner-2") {
      await counter.increment()
      try await Task.sleep(for: .milliseconds(100))
      return expectedData
    }

    async let second: Data = store.data(for: "/banner-2") {
      await counter.increment()
      return Data("other".utf8)
    }

    let (firstResult, secondResult) = try await (first, second)

    XCTAssertEqual(firstResult, expectedData)
    XCTAssertEqual(secondResult, expectedData)
    let count = await counter.current()
    XCTAssertEqual(count, 1)
  }
}
