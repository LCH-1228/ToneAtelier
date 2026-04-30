//
//  ImageClient.swift
//  ToneAtelier
//
//  Created by Codex on 4/25/26.
//

import ComposableArchitecture
import Foundation

struct ImageClient {
  var clearCache: @Sendable () async -> Void
  var fetchData: @Sendable (_ path: String) async throws -> Data
}

extension ImageClient: DependencyKey {
  static var liveValue: ImageClient {
    @Dependency(\.commonClient) var commonClient
    let store = LiveImageStore.shared

    return ImageClient(
      clearCache: {
        await store.clear()
      },
      fetchData: { path in
        try await store.data(for: path) {
          try await commonClient.fetchPhoto(path)
        }
      }
    )
  }

  static let testValue = ImageClient(
    clearCache: {},
    fetchData: { _ in
      throw APIError.transport("ImageClient.fetchData testValue")
    }
  )
}

extension DependencyValues {
  var imageClient: ImageClient {
    get { self[ImageClient.self] }
    set { self[ImageClient.self] = newValue }
  }
}

actor LiveImageStore {
  static let shared = LiveImageStore()

  private var cachedData: [String: Data] = [:]
  private var inFlightTasks: [String: Task<Data, Error>] = [:]
  private let diskStore: LiveImageDiskStore

  init(diskStore: LiveImageDiskStore = .shared) {
    self.diskStore = diskStore
  }

  func clear() async {
    for task in inFlightTasks.values {
      task.cancel()
    }
    inFlightTasks.removeAll()
    cachedData.removeAll()
    await diskStore.clearAll()
    await ChatImageDecodedCache.shared.clear()
  }

  func data(
    for path: String,
    loader: @Sendable @escaping () async throws -> Data
  ) async throws -> Data {
    if let cachedData = cachedData[path] {
      return cachedData
    }

    if let inFlightTask = inFlightTasks[path] {
      return try await inFlightTask.value
    }

    // 디스크 조회. hit 시 메모리에 적재 후 반환.
    if let disk = await diskStore.read(path: path) {
      cachedData[path] = disk
      return disk
    }

    // 네트워크 fetch 후 메모리 + 디스크 동시 저장.
    let task = Task<Data, Error> {
      try await loader()
    }
    inFlightTasks[path] = task

    do {
      let data = try await task.value
      cachedData[path] = data
      await diskStore.write(data, path: path)
      inFlightTasks[path] = nil
      return data
    } catch {
      inFlightTasks[path] = nil
      throw error
    }
  }
}
