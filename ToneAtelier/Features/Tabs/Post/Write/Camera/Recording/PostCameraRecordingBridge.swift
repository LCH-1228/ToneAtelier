//
//  PostCameraRecordingBridge.swift
//  ToneAtelier
//

@preconcurrency import AVFoundation
import OSLog

/// AVCaptureMovieFileOutput 의 일회용 delegate. 결과 URL 또는 실패를 단 한번 전달한다.
final class PostCameraRecordingBridge: NSObject, AVCaptureFileOutputRecordingDelegate, @unchecked Sendable {
  private let onFinish: @Sendable (Result<URL, Error>) -> Void
  private let firedLock = NSLock()
  nonisolated(unsafe) private var hasFired = false

  init(onFinish: @escaping @Sendable (Result<URL, Error>) -> Void) {
    self.onFinish = onFinish
  }

  deinit {
    Logger.postCamera.debug("Deinit: \(String(describing: Self.self), privacy: .public)")
  }

  nonisolated func fileOutput(
    _ output: AVCaptureFileOutput,
    didFinishRecordingTo outputFileURL: URL,
    from connections: [AVCaptureConnection],
    error: Error?
  ) {
    guard claimFiring() else { return }
    if let error {
      onFinish(.failure(error))
    } else {
      onFinish(.success(outputFileURL))
    }
  }

  nonisolated private func claimFiring() -> Bool {
    firedLock.lock()
    defer { firedLock.unlock() }
    guard !hasFired else { return false }
    hasFired = true
    return true
  }
}
