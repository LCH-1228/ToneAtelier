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

  func clear() {
    for task in inFlightTasks.values {
      task.cancel()
    }
    inFlightTasks.removeAll()
    cachedData.removeAll()
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

    let task = Task {
      try await loader()
    }
    inFlightTasks[path] = task

    do {
      let data = try await task.value
      cachedData[path] = data
      inFlightTasks[path] = nil
      return data
    } catch {
      inFlightTasks[path] = nil
      throw error
    }
  }
}
