//
//  VideoLocalStore.swift
//  ToneAtelier
//
//  Created by LCH on 5/5/26.
//

import ComposableArchitecture
import Foundation
import OSLog
import SwiftData

// MARK: - ModelActor

@ModelActor
actor VideoLocalStore {
  // swiftlint:disable:next function_parameter_count
  func upsert(
    userID: String,
    videoID: String,
    progress: Double,
    currentSeconds: Double,
    duration: Double,
    updatedAt: Date
  ) throws {
    let targetUserID = userID
    let targetVideoID = videoID
    var descriptor = FetchDescriptor<StoredVideoProgress>(
      predicate: #Predicate { $0.userID == targetUserID && $0.videoID == targetVideoID }
    )
    descriptor.fetchLimit = 1

    if let existing = try modelContext.fetch(descriptor).first {
      existing.apply(
        progress: progress,
        currentSeconds: currentSeconds,
        duration: duration,
        updatedAt: updatedAt
      )
    } else {
      let entity = StoredVideoProgress(
        userID: userID,
        videoID: videoID,
        progress: progress,
        currentSeconds: currentSeconds,
        duration: duration,
        updatedAt: updatedAt
      )
      modelContext.insert(entity)
    }
    try modelContext.save()
  }

  func progresses(userID: String, videoIDs: [String]) throws -> [String: Double] {
    guard !videoIDs.isEmpty else { return [:] }
    let targetUserID = userID
    let descriptor = FetchDescriptor<StoredVideoProgress>(
      predicate: #Predicate { $0.userID == targetUserID && videoIDs.contains($0.videoID) }
    )
    let stored = try modelContext.fetch(descriptor)
    var map: [String: Double] = [:]
    for entry in stored {
      map[entry.videoID] = entry.progress
    }
    return map
  }

  func progress(userID: String, videoID: String) throws -> VideoProgress? {
    let targetUserID = userID
    let targetVideoID = videoID
    var descriptor = FetchDescriptor<StoredVideoProgress>(
      predicate: #Predicate { $0.userID == targetUserID && $0.videoID == targetVideoID }
    )
    descriptor.fetchLimit = 1
    return try modelContext.fetch(descriptor).first?.asVideoProgress()
  }
}

// MARK: - Dependency Client

struct VideoLocalStoreClient {
  var upsert: @Sendable (
    _ userID: String,
    _ videoID: String,
    _ progress: Double,
    _ currentSeconds: Double,
    _ duration: Double,
    _ updatedAt: Date
  ) async throws -> Void
  var progresses: @Sendable (_ userID: String, _ videoIDs: [String]) async throws -> [String: Double]
  var progress: @Sendable (_ userID: String, _ videoID: String) async throws -> VideoProgress?
}

extension VideoLocalStoreClient: DependencyKey {
  static var liveValue: VideoLocalStoreClient {
    let store = LiveVideoLocalStoreFactory.shared.store
    return VideoLocalStoreClient(
      upsert: { userID, videoID, progress, currentSeconds, duration, updatedAt in
        try await store.upsert(
          userID: userID,
          videoID: videoID,
          progress: progress,
          currentSeconds: currentSeconds,
          duration: duration,
          updatedAt: updatedAt
        )
      },
      progresses: { userID, videoIDs in
        try await store.progresses(userID: userID, videoIDs: videoIDs)
      },
      progress: { userID, videoID in
        try await store.progress(userID: userID, videoID: videoID)
      }
    )
  }

  static let testValue = VideoLocalStoreClient(
    upsert: { _, _, _, _, _, _ in throw APIError.transport("VideoLocalStoreClient.upsert testValue") },
    progresses: { _, _ in throw APIError.transport("VideoLocalStoreClient.progresses testValue") },
    progress: { _, _ in throw APIError.transport("VideoLocalStoreClient.progress testValue") }
  )
}

extension DependencyValues {
  var videoLocalStore: VideoLocalStoreClient {
    get { self[VideoLocalStoreClient.self] }
    set { self[VideoLocalStoreClient.self] = newValue }
  }
}

// MARK: - Live Container Factory

private final class LiveVideoLocalStoreFactory: @unchecked Sendable {
  static let shared = LiveVideoLocalStoreFactory()

  let store: VideoLocalStore

  private init() {
    do {
      let schema = Schema([StoredVideoProgress.self])
      // ChatLocalStore와 동일 default URL을 공유하면 schema 충돌로 write/fetch가 silent fail 한다.
      let storeURL = URL.applicationSupportDirectory
        .appending(component: "VideoProgress.sqlite")
      let configuration = ModelConfiguration(
        schema: schema,
        url: storeURL
      )
      let container = try ModelContainer(for: schema, configurations: configuration)
      self.store = VideoLocalStore(modelContainer: container)
    } catch {
      Logger.videoStorage.fault(
        "VideoLocalStore bootstrap failed: \(error.localizedDescription, privacy: .public)"
      )
      fatalError("VideoLocalStore bootstrap failed: \(error)")
    }
  }
}
