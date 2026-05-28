//
//  InlineVideoCoordinator.swift
//  ToneAtelier
//
//  Created by Codex on 5/4/26.
//

import Combine
import Foundation

/// 앱 전체에서 한 번에 한 `VideoMediaView`만 인라인 재생되도록 강제하는 조정자.
@MainActor
final class InlineVideoCoordinator: ObservableObject {
  static let shared = InlineVideoCoordinator()

  @Published private(set) var activeID: UUID?
  private(set) var activePath: String?
  private(set) var activeHolder: VideoPlayerHolder?
  private(set) var activeStreamURL: URL?
  private(set) var activeLoader: AuthenticatedAssetLoader?

  private init() {}

  func claim(
    _ id: UUID,
    path: String,
    holder: VideoPlayerHolder,
    loader: AuthenticatedAssetLoader?,
    streamURL: URL
  ) {
    activeID = id
    activePath = path
    activeHolder = holder
    activeLoader = loader
    activeStreamURL = streamURL
  }

  func release(_ id: UUID) {
    if activeID == id {
      activeID = nil
      activePath = nil
      activeHolder = nil
      activeStreamURL = nil
      activeLoader = nil
    }
  }
}
