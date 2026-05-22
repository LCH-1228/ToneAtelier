//
//  VideoPlayerHolder.swift
//  ToneAtelier
//
//  Created by Codex on 5/5/26.
//

import AVFoundation
import AVKit
import Observation
import OSLog
import SwiftUI
import UIKit

@MainActor
@Observable
final class VideoPlayerHolder: NSObject {
  let player = AVPlayer()
  // PiP controller 가 참조하므로 view tree 변경에도 invalid 가 되지 않게 영구 보유.
  let playerLayer: AVPlayerLayer

  var currentTime: TimeInterval = 0
  var duration: TimeInterval = 0
  var isPlaying = false
  var isBuffering = false
  var isSeeking = false
  var isPiPActive = false

  private var timeObserverToken: Any?
  private var statusObserver: NSKeyValueObservation?
  private var rateObserver: NSKeyValueObservation?
  private var bufferingObserver: NSKeyValueObservation?
  private var bufferingDelayTask: Task<Void, Never>?
  private var lastStreamURL: URL?
  private var pendingResumeTime: CMTime = .zero
  private var playbackRate: Float = 1.0
  private var preferredPeakBitRate: Double = 0
  private var pipController: AVPictureInPictureController?
  // willStart 시점은 view 변경과 충돌해 PiP 가 풀리므로 didStart 시점에 풀스크린 종료 등 host 정리.
  var onDidStartPiP: (() -> Void)?
  var onPlaybackFailure: ((NSError?) -> Void)?

  override init() {
    let layer = AVPlayerLayer()
    self.playerLayer = layer
    super.init()
    player.automaticallyWaitsToMinimizeStalling = true
    layer.player = player
    layer.videoGravity = .resizeAspect
    layer.backgroundColor = UIColor.black.cgColor
    configureAudioSession()
    setupPiPController()
    attachPlayerObservers()
  }

  private func setupPiPController() {
    guard AVPictureInPictureController.isPictureInPictureSupported() else { return }
    let controller = AVPictureInPictureController(playerLayer: playerLayer)
    controller?.canStartPictureInPictureAutomaticallyFromInline = true
    controller?.delegate = self
    pipController = controller
  }

  deinit {
    Logger.videoPlayer.notice("HLS holder deinit")
  }

  // MARK: - Audio session / PiP

  // .playback 카테고리 — silent switch 무시 + PiP/백그라운드 재생 가능.
  private func configureAudioSession() {
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(.playback, mode: .moviePlayback)
      try session.setActive(true, options: [])
    } catch {
      Logger.videoPlayer.error("AVAudioSession setup failed: \(error.localizedDescription, privacy: .public)")
    }
  }

  func startPiP() {
    pipController?.startPictureInPicture()
  }

  func stopPiP() {
    pipController?.stopPictureInPicture()
  }

  func togglePiP() {
    guard let controller = pipController else { return }
    if controller.isPictureInPictureActive {
      controller.stopPictureInPicture()
    } else {
      controller.startPictureInPicture()
    }
  }

  // MARK: - Public API

  func replaceURL(_ url: URL, initialResume: TimeInterval? = nil) {
    guard lastStreamURL != url else { return }
    if let initialResume, initialResume > 0 {
      pendingResumeTime = CMTime(seconds: initialResume, preferredTimescale: 600)
    } else if lastStreamURL != nil {
      pendingResumeTime = player.currentTime()
    } else {
      pendingResumeTime = .zero
    }
    lastStreamURL = url
    let item = AVPlayerItem(url: url)
    item.preferredPeakBitRate = preferredPeakBitRate
    detachItemObservers()
    player.replaceCurrentItem(with: item)
    attachItemObservers(item: item)
    Logger.videoPlayer.notice("HLS replaceURL host=\(url.host ?? "?", privacy: .public)")
  }

  func resetForNewVideo() {
    lastStreamURL = nil
    pendingResumeTime = .zero
    currentTime = 0
    duration = 0
    isPlaying = false
    isBuffering = false
    isSeeking = false
    bufferingDelayTask?.cancel()
    bufferingDelayTask = nil
  }

  func setPreferredPeakBitRate(_ rate: Double) {
    preferredPeakBitRate = rate
    player.currentItem?.preferredPeakBitRate = rate
  }

  func setPlaybackRate(_ rate: Float) {
    playbackRate = rate
    if isPlaying {
      player.rate = rate
    }
  }

  func playPauseToggle() {
    if isPlaying {
      player.pause()
    } else {
      player.rate = playbackRate
    }
  }

  func skip(by delta: Double) {
    let target = max(0, min(duration, currentTime + delta))
    seek(to: target)
  }

  // tolerance .positiveInfinity 로 nearest sync frame 빠른 seek + isSeeking 가드로 progress bar jiggle 차단.
  func seek(to time: TimeInterval) {
    currentTime = time
    isSeeking = true
    player.seek(
      to: CMTime(seconds: time, preferredTimescale: 600),
      toleranceBefore: .positiveInfinity,
      toleranceAfter: .positiveInfinity
    ) { [weak self] finished in
      Task { @MainActor [weak self] in
        guard let self else { return }
        if finished { self.isSeeking = false }
      }
    }
  }

  func teardown() {
    detach()
    player.pause()
    player.replaceCurrentItem(with: nil)
    Logger.videoPlayer.notice("HLS teardown")
  }

  // MARK: - Observers

  private func attachPlayerObservers() {
    let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
    timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
      MainActor.assumeIsolated {
        guard let self else { return }
        guard self.player.rate > 0, self.player.currentItem != nil else { return }
        guard !self.isSeeking else { return }
        let cur = CMTimeGetSeconds(time)
        let dur = CMTimeGetSeconds(self.player.currentItem?.duration ?? .zero)
        self.currentTime = cur.isFinite ? cur : 0
        self.duration = dur.isFinite ? dur : 0
      }
    }
    rateObserver = player.observe(\.rate, options: [.new]) { [weak self] observed, _ in
      Task { @MainActor [weak self] in
        guard let self else { return }
        let playing = observed.rate > 0
        if self.isPlaying != playing { self.isPlaying = playing }
      }
    }
  }

  private func attachItemObservers(item: AVPlayerItem) {
    statusObserver = item.observe(\.status, options: [.new]) { [weak self] observed, _ in
      Task { @MainActor [weak self] in
        guard let self else { return }
        switch observed.status {
        case .readyToPlay:
          Logger.videoPlayer.notice("HLS readyToPlay")
          self.resumeAndPlay()
        case .failed:
          let nsError = observed.error as NSError?
          let reason = nsError?.localizedDescription ?? "unknown"
          Logger.videoPlayer.error("HLS item failed: \(reason, privacy: .public)")
          self.onPlaybackFailure?(nsError)
        case .unknown:
          break
        @unknown default:
          break
        }
      }
    }
    bufferingObserver = item.observe(\.isPlaybackLikelyToKeepUp, options: [.new]) { [weak self] observed, _ in
      Task { @MainActor [weak self] in
        guard let self else { return }
        let likelyKeepUp = observed.isPlaybackLikelyToKeepUp
        if likelyKeepUp {
          self.bufferingDelayTask?.cancel()
          self.bufferingDelayTask = nil
          if self.isBuffering {
            withAnimation(.easeInOut(duration: 0.18)) {
              self.isBuffering = false
            }
          }
        } else {
          self.bufferingDelayTask?.cancel()
          self.bufferingDelayTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled, let self else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
              self.isBuffering = true
            }
          }
        }
      }
    }
  }

  private func resumeAndPlay() {
    let resume = pendingResumeTime
    if resume.seconds > 0 {
      pendingResumeTime = .zero
      player.seek(to: resume, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
        Task { @MainActor [weak self] in
          guard let self else { return }
          self.player.rate = self.playbackRate
        }
      }
    } else {
      player.rate = playbackRate
    }
  }

  private func detach() {
    detachItemObservers()
    if let token = timeObserverToken {
      player.removeTimeObserver(token)
      timeObserverToken = nil
    }
    rateObserver?.invalidate()
    rateObserver = nil
    bufferingDelayTask?.cancel()
    bufferingDelayTask = nil
  }

  private func detachItemObservers() {
    statusObserver?.invalidate()
    statusObserver = nil
    bufferingObserver?.invalidate()
    bufferingObserver = nil
  }
}

// MARK: - PiP delegate

extension VideoPlayerHolder: AVPictureInPictureControllerDelegate {
  nonisolated func pictureInPictureControllerWillStartPictureInPicture(
    _ pictureInPictureController: AVPictureInPictureController
  ) {
    Task { @MainActor [weak self] in
      self?.isPiPActive = true
    }
    Logger.videoPlayer.notice("PiP willStart")
  }

  nonisolated func pictureInPictureControllerDidStartPictureInPicture(
    _ pictureInPictureController: AVPictureInPictureController
  ) {
    Task { @MainActor [weak self] in
      self?.onDidStartPiP?()
    }
    Logger.videoPlayer.notice("PiP didStart")
  }

  nonisolated func pictureInPictureControllerDidStopPictureInPicture(
    _ pictureInPictureController: AVPictureInPictureController
  ) {
    Task { @MainActor [weak self] in
      self?.isPiPActive = false
      // 풀스크린 종료와 같은 frame 의 race 로 rate=0 떨어지는 케이스 회복.
      try? await Task.sleep(nanoseconds: 200_000_000)
      guard let self else { return }
      if self.player.rate == 0, self.player.currentItem != nil {
        self.player.rate = self.playbackRate
      }
    }
    Logger.videoPlayer.notice("PiP didStop")
  }

  nonisolated func pictureInPictureController(
    _ pictureInPictureController: AVPictureInPictureController,
    failedToStartPictureInPictureWithError error: Error
  ) {
    Task { @MainActor [weak self] in
      self?.isPiPActive = false
    }
    Logger.videoPlayer.error("PiP failedToStart: \(error.localizedDescription, privacy: .public)")
  }

  // 이 콜백 없이는 controller 가 invalid 로 남아 두 번째 PiP 시작이 무시된다.
  nonisolated func pictureInPictureController(
    _ pictureInPictureController: AVPictureInPictureController,
    restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
  ) {
    completionHandler(true)
  }
}
