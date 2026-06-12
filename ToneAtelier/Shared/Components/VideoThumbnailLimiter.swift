//
//  VideoThumbnailLimiter.swift
//  ToneAtelier
//

import Foundation

/// list 셀의 video thumbnail 다수가 동시에 AVAssetImageGenerator 를 돌려 HTTP/2 connection
/// pool 을 포화시키는 현상을 막기 위한 동시성 제한. polling 기반(50ms) 으로 cancellation 안전.
actor VideoThumbnailLimiter {
  static let shared = VideoThumbnailLimiter(maxConcurrent: 4)

  private let maxConcurrent: Int
  private var active = 0

  init(maxConcurrent: Int) {
    self.maxConcurrent = maxConcurrent
  }

  /// slot 확보. cancel 시 false.
  func acquire() async -> Bool {
    while active >= maxConcurrent {
      do {
        try await Task.sleep(nanoseconds: 50_000_000)
      } catch {
        return false
      }
    }
    active += 1
    return true
  }

  func release() {
    if active > 0 { active -= 1 }
  }
}
