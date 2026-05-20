//
//  Logger+App.swift
//  ToneAtelier
//
//  Created by LCH on 4/24/26.
//

import OSLog

extension Logger {
  private static let subsystem = Bundle.main.bundleIdentifier ?? "com.mitti.ToneAtelier"

  enum Category: String {
    case authSession = "AuthSession"
    case chatRoom = "ChatRoom"
    case chatUnread = "ChatUnread"
    case makeAutoTune = "MakeAutoTune"
    case postCamera = "PostCamera"
    case push = "Push"
    case videoPlayer = "VideoPlayer"
    case videoStorage = "VideoStorage"
  }

  static func app(_ category: Category) -> Logger {
    Logger(subsystem: subsystem, category: category.rawValue)
  }

  // MARK: - Predefined

  nonisolated static let authSession = app(.authSession)
  nonisolated static let chatRoom = app(.chatRoom)
  nonisolated static let chatUnread = app(.chatUnread)
  nonisolated static let makeAutoTune = app(.makeAutoTune)
  nonisolated static let postCamera = app(.postCamera)
  nonisolated static let push = app(.push)
  nonisolated static let videoPlayer = app(.videoPlayer)
  nonisolated static let videoStorage = app(.videoStorage)
}
