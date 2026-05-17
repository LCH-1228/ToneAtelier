//
//  PostCameraFrameRelay.swift
//  ToneAtelier
//
//  PostCameraSession 의 라이브 프레임을 SwiftUI 가 관찰 가능한 @Published 로 throttle 해 노출.
//  Sheet 의 cell 들이 매 frame tick 마다 자기 filter 로 카메라를 라이브 미리보기할 수 있게 한다.
//

import Combine
import CoreImage
import Foundation

@MainActor
final class PostCameraFrameRelay: ObservableObject {
  @Published private(set) var latestFrame: CIImage?
  /// frame 이 갱신될 때마다 +1. SwiftUI .task(id:) 에 포함시켜 cell 재렌더 트리거 키로 사용.
  @Published private(set) var frameTick: Int = 0

  private var lastEmit: Date = .distantPast
  /// cell 들이 라이브하게 보이도록 충분히 부드럽되 GPU 부담은 줄이는 10fps.
  private let minInterval: TimeInterval = 0.1

  /// session 콜백(임의 큐) → 메인큐로 throttled 전달.
  nonisolated func ingest(_ frame: CIImage) {
    Task { @MainActor [weak self] in
      guard let self else { return }
      let now = Date()
      guard now.timeIntervalSince(self.lastEmit) >= self.minInterval else { return }
      self.lastEmit = now
      self.latestFrame = frame
      self.frameTick &+= 1
    }
  }
}
