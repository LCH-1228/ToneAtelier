//
//  HLSVideoPlayerView.swift
//  ToneAtelier
//
//  Created by Codex on 5/5/26.
//

import AVFoundation
import OSLog
import SwiftUI
import UIKit

struct HLSVideoPlayerView: View {
  let streamURL: URL
  let cues: [SubtitleCue]
  let posterPath: String?
  let preferredPeakBitRate: Double
  let qualities: [StreamQualityDTO]
  let selectedQuality: String?
  let subtitles: [StreamSubtitleDTO]
  let selectedSubtitle: StreamSubtitleDTO?
  let initialResumeTime: TimeInterval?
  let onQualitySelect: (String?) -> Void
  let onSubtitleSelect: (StreamSubtitleDTO?) -> Void
  let onTimeUpdate: (TimeInterval, TimeInterval) -> Void
  let isFullscreen: Bool
  let onFullscreenToggle: () -> Void

  let holder: VideoPlayerHolder

  @State private var isControlsVisible = true
  @State private var hideTask: Task<Void, Never>?
  @State private var isScrubbing = false
  @State private var scrubTime: TimeInterval = 0
  @State private var playbackRate: Float = 1.0
  @State private var isSettingsOpen = false

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        videoLayer
        VideoSubtitleOverlay(text: activeCue?.text)
        VideoControlsOverlay(
          width: proxy.size.width,
          isVisible: isControlsVisible,
          isFullscreen: isFullscreen,
          isPlaying: holder.isPlaying,
          isBuffering: holder.isBuffering,
          currentTime: displayTime,
          duration: holder.duration,
          isScrubbing: isScrubbing,
          isSettingsOpen: $isSettingsOpen,
          playbackRate: playbackRate,
          qualities: qualities,
          selectedQuality: selectedQuality,
          subtitles: subtitles,
          selectedSubtitle: selectedSubtitle,
          onPlayPause: handlePlayPauseTap,
          onSkip: handleSkip,
          onScrubChange: handleScrubChange,
          onScrubEnd: handleScrubEnd,
          onSpeedSelect: handleSpeedSelect,
          onQualitySelect: { quality in
            onQualitySelect(quality)
            scheduleAutoHide()
          },
          onSubtitleSelect: { subtitle in
            onSubtitleSelect(subtitle)
            scheduleAutoHide()
          },
          onFullscreenToggle: {
            onFullscreenToggle()
            showControls()
          },
          isPiPActive: holder.isPiPActive,
          onPiPToggle: {
            holder.togglePiP()
            showControls()
          }
        )
      }
      .contentShape(.rect)
      .onTapGesture { toggleControls() }
    }
    .onChange(of: streamURL) { _, newValue in
      holder.replaceURL(newValue, initialResume: initialResumeTime)
    }
    .onChange(of: preferredPeakBitRate) { _, newValue in
      holder.setPreferredPeakBitRate(newValue)
    }
    .onChange(of: holder.currentTime) { _, _ in
      onTimeUpdate(holder.currentTime, holder.duration)
    }
    .onChange(of: isSettingsOpen) { _, opened in
      if opened {
        isControlsVisible = true
        hideTask?.cancel()
        hideTask = nil
      } else {
        scheduleAutoHide()
      }
    }
    .onAppear {
      holder.setPreferredPeakBitRate(preferredPeakBitRate)
      holder.setPlaybackRate(playbackRate)
      holder.replaceURL(streamURL, initialResume: initialResumeTime)
    }
  }

  // MARK: - Layers

  private var videoLayer: some View {
    PlayerLayerHost(holder: holder)
      .background(Color.black)
  }

  private var displayTime: TimeInterval {
    isScrubbing ? scrubTime : holder.currentTime
  }

  private var activeCue: SubtitleCue? {
    cues.first(where: { displayTime >= $0.start && displayTime <= $0.end })
  }

  // MARK: - Controls

  private func handlePlayPauseTap() {
    holder.playPauseToggle()
    showControls()
  }

  private func handleSkip(_ delta: Double) {
    holder.skip(by: delta)
    showControls()
  }

  private func handleScrubChange(_ time: TimeInterval) {
    if !isScrubbing {
      isScrubbing = true
      hideTask?.cancel()
    }
    scrubTime = time
  }

  private func handleScrubEnd(_ time: TimeInterval) {
    holder.seek(to: time)
    isScrubbing = false
    scheduleAutoHide()
  }

  private func handleSpeedSelect(_ rate: Float) {
    playbackRate = rate
    holder.setPlaybackRate(rate)
    scheduleAutoHide()
  }

  private func toggleControls() {
    if isControlsVisible {
      hideControls()
    } else {
      showControls()
    }
  }

  private func showControls() {
    isControlsVisible = true
    scheduleAutoHide()
  }

  private func hideControls() {
    hideTask?.cancel()
    hideTask = nil
    isControlsVisible = false
  }

  private func scheduleAutoHide() {
    hideTask?.cancel()
    guard holder.isPlaying, !isScrubbing, !isSettingsOpen else { return }
    hideTask = Task { @MainActor in
      try? await Task.sleep(nanoseconds: 4_000_000_000)
      guard !Task.isCancelled else { return }
      if holder.isPlaying, !isScrubbing, !isSettingsOpen {
        isControlsVisible = false
      }
    }
  }
}

// MARK: - AVPlayerLayer 호스팅

// host view 가 재마운트돼도 holder 가 layer 를 영구 보유 → PiP controller 가 valid 상태 유지.
private struct PlayerLayerHost: UIViewRepresentable {
  let holder: VideoPlayerHolder

  func makeUIView(context: Context) -> PlayerLayerHostingView {
    let view = PlayerLayerHostingView()
    view.backgroundColor = .black
    // PiP active 동안은 layer 가 시스템에 있어 끌어오면 PiP 가 풀린다.
    if !holder.isPiPActive {
      view.host(holder.playerLayer)
    }
    return view
  }

  func updateUIView(_ uiView: PlayerLayerHostingView, context: Context) {
    if !holder.isPiPActive, uiView.hostedLayer !== holder.playerLayer {
      uiView.host(holder.playerLayer)
    }
  }
}

private final class PlayerLayerHostingView: UIView {
  weak var hostedLayer: AVPlayerLayer?

  func host(_ layer: AVPlayerLayer) {
    guard hostedLayer !== layer else { return }
    hostedLayer?.removeFromSuperlayer()
    hostedLayer = layer
    self.layer.addSublayer(layer)
    setNeedsLayout()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    hostedLayer?.frame = bounds
  }

  override func didMoveToSuperview() {
    super.didMoveToSuperview()
    // 새 host view 가 동일 layer 를 sublayer 로 가져갔으면 강제 detach 시 영상 사라지므로 weak 참조만 정리.
    if superview == nil {
      hostedLayer = nil
    }
  }
}
