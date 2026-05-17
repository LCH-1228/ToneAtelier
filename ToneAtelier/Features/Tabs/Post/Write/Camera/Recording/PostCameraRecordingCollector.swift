//
//  PostCameraRecordingCollector.swift
//  ToneAtelier
//

import Foundation

/// 원본 / 필터본 두 콜백을 모아 PostCameraRecordedClip 으로 묶어주는 일회용 collector.
/// saveFiltered = false 면 원본 결과만 기다리고 즉시 발사.
final class PostCameraRecordingCollector: @unchecked Sendable {
  private let saveFiltered: Bool
  private let onFinish: @Sendable (Result<PostCameraRecordedClip, Error>) -> Void
  private let lock = NSLock()
  private var originalResult: Result<URL, Error>?
  private var filteredResult: Result<URL, Error>?
  private var hasFired = false

  init(
    saveFiltered: Bool,
    onFinish: @escaping @Sendable (Result<PostCameraRecordedClip, Error>) -> Void
  ) {
    self.saveFiltered = saveFiltered
    self.onFinish = onFinish
  }

  func handleOriginal(_ result: Result<URL, Error>) {
    lock.lock()
    originalResult = result
    let payload = readyPayload()
    lock.unlock()
    if let payload { onFinish(.success(payload)) }
  }

  func handleFiltered(_ result: Result<URL, Error>) {
    lock.lock()
    filteredResult = result
    let payload = readyPayload()
    lock.unlock()
    if let payload { onFinish(.success(payload)) }
  }

  private func readyPayload() -> PostCameraRecordedClip? {
    guard !hasFired else { return nil }
    let originalReady = originalResult != nil
    let filteredReady = !saveFiltered || filteredResult != nil
    guard originalReady, filteredReady else { return nil }
    hasFired = true
    let originalURL = originalResult.flatMap { try? $0.get() }
    let filteredURL = filteredResult.flatMap { try? $0.get() }
    return PostCameraRecordedClip(
      originalURL: originalURL,
      filteredURL: filteredURL
    )
  }
}
