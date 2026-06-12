//
//  PostCameraSettingsStore.swift
//  ToneAtelier
//

import ComposableArchitecture
import Foundation
import OSLog

struct PostCameraSettingsStore: Sendable {
  var load: @Sendable () -> PostCameraSettings
  var save: @Sendable (PostCameraSettings) -> Void
}

extension PostCameraSettingsStore: DependencyKey {
  nonisolated private static let storageKey = "post.camera.settings.v1"

  static let liveValue = PostCameraSettingsStore(
    load: {
      guard let data = UserDefaults.standard.data(forKey: storageKey) else {
        return .default
      }
      do {
        return try JSONDecoder().decode(PostCameraSettings.self, from: data)
      } catch {
        Logger.postCamera.error("settings decode failed: \(error.localizedDescription, privacy: .public)")
        return .default
      }
    },
    save: { settings in
      do {
        let data = try JSONEncoder().encode(settings)
        UserDefaults.standard.set(data, forKey: storageKey)
      } catch {
        Logger.postCamera.error("settings encode failed: \(error.localizedDescription, privacy: .public)")
      }
    }
  )

  static let testValue = PostCameraSettingsStore(
    load: { .default },
    save: { _ in }
  )
}

extension DependencyValues {
  var postCameraSettingsStore: PostCameraSettingsStore {
    get { self[PostCameraSettingsStore.self] }
    set { self[PostCameraSettingsStore.self] = newValue }
  }
}
