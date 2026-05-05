//
//  StoredVideoProgress.swift
//  ToneAtelier
//
//  Created by LCH on 5/5/26.
//

import Foundation
import SwiftData

// (userID, videoID) 복합 unique는 SwiftData가 직접 지원하지 않아 application logic으로 보장한다.
@Model
final class StoredVideoProgress {
  var userID: String
  var videoID: String
  var progress: Double
  var currentSeconds: Double
  var duration: Double
  var updatedAt: Date

  init(
    userID: String,
    videoID: String,
    progress: Double,
    currentSeconds: Double,
    duration: Double,
    updatedAt: Date
  ) {
    self.userID = userID
    self.videoID = videoID
    self.progress = progress
    self.currentSeconds = currentSeconds
    self.duration = duration
    self.updatedAt = updatedAt
  }
}

struct VideoProgress: Equatable, Sendable {
  let userID: String
  let videoID: String
  let progress: Double
  let currentSeconds: Double
  let duration: Double
  let updatedAt: Date
}

extension StoredVideoProgress {
  func asVideoProgress() -> VideoProgress {
    VideoProgress(
      userID: userID,
      videoID: videoID,
      progress: progress,
      currentSeconds: currentSeconds,
      duration: duration,
      updatedAt: updatedAt
    )
  }

  func apply(progress: Double, currentSeconds: Double, duration: Double, updatedAt: Date) {
    self.progress = progress
    self.currentSeconds = currentSeconds
    self.duration = duration
    self.updatedAt = updatedAt
  }
}
