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
  private var temporaryDirectories: [URL] = []

  override func tearDown() async throws {
    for url in temporaryDirectories {
      try? FileManager.default.removeItem(at: url)
    }
    temporaryDirectories.removeAll()
    try await super.tearDown()
  }

  private func makeIsolatedStore() -> LiveImageStore {
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("ImageClientTests-\(UUID().uuidString)", isDirectory: true)
    temporaryDirectories.append(tempDir)
    let diskStore = LiveImageDiskStore(directoryURL: tempDir)
    return LiveImageStore(diskStore: diskStore)
  }

  func testLiveImageStoreCachesLoadedData() async throws {
    let store = makeIsolatedStore()
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
    let store = makeIsolatedStore()
    let counter = ImageLoadCounter()
    let expectedData = Data("shared-image".utf8)

    let firstTask = Task {
      try await store.data(for: "/banner-2") {
        await counter.increment()
        try await Task.sleep(for: .milliseconds(100))
        return expectedData
      }
    }

    // first가 actor에 진입해 in-flight 등록을 마칠 시간을 보장한다.
    try await Task.sleep(for: .milliseconds(20))

    let secondTask = Task {
      try await store.data(for: "/banner-2") {
        await counter.increment()
        return Data("other".utf8)
      }
    }

    let firstResult = try await firstTask.value
    let secondResult = try await secondTask.value

    XCTAssertEqual(firstResult, expectedData)
    XCTAssertEqual(secondResult, expectedData)
    let count = await counter.current()
    XCTAssertEqual(count, 1)
  }
}
