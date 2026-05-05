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
          }
        )
      }
      .contentShape(.rect)
      .onTapGesture { toggleControls() }
    }
    .onChange(of: streamURL) { _, newValue in
      holder.replaceURL(newValue)
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
      holder.replaceURL(streamURL)
    }
  }

  // MARK: - Layers

  private var videoLayer: some View {
    PlayerLayerHost(player: holder.player)
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

private struct PlayerLayerHost: UIViewRepresentable {
  let player: AVPlayer

  func makeUIView(context: Context) -> PlayerLayerHostingView {
    let view = PlayerLayerHostingView()
    view.backgroundColor = .black
    view.playerLayer?.player = player
    view.playerLayer?.videoGravity = .resizeAspect
    view.playerLayer?.backgroundColor = UIColor.black.cgColor
    return view
  }

  func updateUIView(_ uiView: PlayerLayerHostingView, context: Context) {
    if uiView.playerLayer?.player !== player {
      uiView.playerLayer?.player = player
    }
  }
}

private final class PlayerLayerHostingView: UIView {
  override class var layerClass: AnyClass { AVPlayerLayer.self }
  // layerClass override 로 항상 AVPlayerLayer — force_cast 룰 회피용 옵셔널.
  var playerLayer: AVPlayerLayer? { layer as? AVPlayerLayer }
}
