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
  /// 다운로드된 raw Data를 디스크 캐시에서 찾아 파일 URL을 반환한다.
  /// 캐시 미스 시 `fetchData` 흐름으로 다운로드 후 디스크에 적재된 URL을 반환한다.
  /// `quickLookPreview` 등 파일 URL이 필요한 SwiftUI 모디파이어용.
  var localFileURL: @Sendable (_ path: String) async throws -> URL
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
        try await store.data(for: path) { ifNoneMatch in
          try await commonClient.fetchPhoto(path, ifNoneMatch)
        }
      },
      localFileURL: { path in
        // 디스크 hit 보장을 위해 fetchData 흐름을 한 번 거치게 한다.
        // 이미 캐시되어 있으면 메모리/디스크 hit으로 즉시 반환되어 비용 무시 가능.
        _ = try await store.data(for: path) { ifNoneMatch in
          try await commonClient.fetchPhoto(path, ifNoneMatch)
        }
        return await LiveImageDiskStore.shared.fileURL(for: path)
      }
    )
  }

  static let testValue = ImageClient(
    clearCache: {},
    fetchData: { _ in
      throw APIError.transport("ImageClient.fetchData testValue")
    },
    localFileURL: { _ in
      throw APIError.transport("ImageClient.localFileURL testValue")
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

  static let memoryCostLimit = 50 * 1024 * 1024

  private let cachedData: NSCache<NSString, NSData> = {
    let cache = NSCache<NSString, NSData>()
    cache.totalCostLimit = LiveImageStore.memoryCostLimit
    return cache
  }()
  private var inFlightTasks: [String: Task<Data, Error>] = [:]
  private var etagByPath: [String: String] = [:]
  private let diskStore: LiveImageDiskStore

  init(diskStore: LiveImageDiskStore = .shared) {
    self.diskStore = diskStore
  }

  func clear() async {
    for task in inFlightTasks.values {
      task.cancel()
    }
    inFlightTasks.removeAll()
    etagByPath.removeAll()
    cachedData.removeAllObjects()
    await diskStore.clearAll()
    await ChatImageDecodedCache.shared.clear()
  }

  func data(
    for path: String,
    loader: @Sendable @escaping (_ ifNoneMatch: String?) async throws -> ImageFetchResult
  ) async throws -> Data {
    if let cached = cachedData.object(forKey: path as NSString) {
      return cached as Data
    }

    if let inFlightTask = inFlightTasks[path] {
      return try await inFlightTask.value
    }

    // 디스크 조회. hit 시 메모리에 적재 후 반환.
    if let disk = await diskStore.read(path: path) {
      cachedData.setObject(disk as NSData, forKey: path as NSString, cost: disk.count)
      return disk
    }

    // 네트워크 fetch — 직전 ETag 가 있으면 If-None-Match 부착.
    let knownETag = etagByPath[path]
    let task = Task<Data, Error> { [weak self] in
      let result = try await loader(knownETag)
      switch result {
      case let .fresh(data, eTag):
        if let eTag, let self {
          await self.setETag(eTag, for: path)
        }
        return data
      case .notModified:
        // memory/disk cache 가 위에서 miss 했으니 304 라도 실제 데이터 없음 — If-None-Match 없이 재요청.
        let retry = try await loader(nil)
        guard case let .fresh(data, eTag) = retry else {
          throw APIError.transport("unexpected non-fresh on If-None-Match retry")
        }
        if let eTag, let self {
          await self.setETag(eTag, for: path)
        }
        return data
      }
    }
    inFlightTasks[path] = task

    do {
      let data = try await task.value
      cachedData.setObject(data as NSData, forKey: path as NSString, cost: data.count)
      await diskStore.write(data, path: path)
      inFlightTasks[path] = nil
      return data
    } catch {
      inFlightTasks[path] = nil
      throw error
    }
  }

  private func setETag(_ etag: String, for path: String) {
    etagByPath[path] = etag
  }
}
