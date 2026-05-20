//
//  VideoControlsOverlay.swift
//  ToneAtelier
//
//  Created by Codex on 5/5/26.
//

import SwiftUI

struct VideoControlsOverlay: View {
  let width: CGFloat
  let isVisible: Bool
  let isFullscreen: Bool
  let isPlaying: Bool
  let isBuffering: Bool
  let currentTime: TimeInterval
  let duration: TimeInterval
  let isScrubbing: Bool
  @Binding var isSettingsOpen: Bool
  let playbackRate: Float
  let qualities: [StreamQualityDTO]
  let selectedQuality: String?
  let subtitles: [StreamSubtitleDTO]
  let selectedSubtitle: StreamSubtitleDTO?

  let onPlayPause: () -> Void
  let onSkip: (Double) -> Void
  let onScrubChange: (TimeInterval) -> Void
  let onScrubEnd: (TimeInterval) -> Void
  let onSpeedSelect: (Float) -> Void
  let onQualitySelect: (String?) -> Void
  let onSubtitleSelect: (StreamSubtitleDTO?) -> Void
  let onFullscreenToggle: () -> Void
  let isPiPActive: Bool
  let onPiPToggle: () -> Void

  var body: some View {
    ZStack {
      Color.black.opacity(0.30)
      topRight
      centerControls
      bottomBar
    }
    .opacity(isVisible ? 1 : 0)
    .allowsHitTesting(isVisible)
    .animation(.easeInOut(duration: 0.2), value: isVisible)
  }

  // MARK: - Top right

  private var topRight: some View {
    VStack {
      HStack(spacing: 8) {
        Spacer(minLength: 0)
        captionsButton
        airPlayButton
        settingsMenu
      }
      .padding(.horizontal, 16)
      .padding(.top, 16)
      Spacer(minLength: 0)
    }
  }

  private var airPlayButton: some View {
    VideoRoutePickerButton(tintColor: .white)
      .frame(width: 40, height: 40)
      .glassEffectCompatible(.regularInteractive, in: .circle)
      .accessibilityLabel("AirPlay")
      .accessibilityIdentifier("video_player_airplay")
  }

  private var pipButton: some View {
    Button(action: onPiPToggle) {
      Image(systemName: isPiPActive ? "pip.exit" : "pip.enter")
        .font(.system(size: 16, weight: .regular))
        .foregroundStyle(.white)
        .frame(width: 36, height: 36)
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .glassEffectCompatible(.regularInteractive, in: .circle)
    .accessibilityLabel(isPiPActive ? "PiP 종료" : "PiP")
    .accessibilityIdentifier("video_player_pip")
  }

  @ViewBuilder
  private var captionsButton: some View {
    if subtitles.isEmpty {
      EmptyView()
    } else {
      Menu {
        Button("자막 끄기") { onSubtitleSelect(nil) }
        ForEach(subtitles, id: \.language) { sub in
          Button {
            onSubtitleSelect(sub)
          } label: {
            if selectedSubtitle?.language == sub.language {
              Label(sub.name, systemImage: "checkmark")
            } else {
              Text(sub.name)
            }
          }
        }
      } label: {
        Image(systemName: selectedSubtitle == nil ? "captions.bubble" : "captions.bubble.fill")
          .font(.system(size: 18, weight: .regular))
          .foregroundStyle(.white)
          .frame(width: 40, height: 40)
          .contentShape(.rect)
      }
      .glassEffectCompatible(.regularInteractive, in: .circle)
      .accessibilityLabel("자막")
      .accessibilityIdentifier("video_player_captions")
    }
  }

  private var settingsMenu: some View {
    Button {
      isSettingsOpen.toggle()
    } label: {
      Image(systemName: "gearshape.fill")
        .font(.system(size: 18, weight: .regular))
        .foregroundStyle(.white)
        .frame(width: 40, height: 40)
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .glassEffectCompatible(.regularInteractive, in: .circle)
    .accessibilityLabel("설정")
    .accessibilityIdentifier("video_player_settings")
    // arrowEdge: .top 으로 panel top 을 톱니바퀴 아래에 고정 — 섹션 펼침 시 bottom 만 확장.
    .popover(isPresented: $isSettingsOpen, arrowEdge: .top) {
      VideoSettingsPanel(
        playbackRate: playbackRate,
        qualities: qualities,
        selectedQuality: selectedQuality,
        onSpeedSelect: onSpeedSelect,
        onQualitySelect: onQualitySelect
      )
    }
  }

  // MARK: - Center

  @ViewBuilder
  private var centerControls: some View {
    if isBuffering {
      ProgressView()
        .progressViewStyle(.circular)
        .controlSize(.large)
        .tint(.white)
        .accessibilityIdentifier("video_player_buffering")
    } else {
      HStack(spacing: 40) {
        skipButton(delta: -10, systemName: "gobackward.10")
        playPauseButton
        skipButton(delta: 10, systemName: "goforward.10")
      }
    }
  }

  // glass 배경은 stable Circle 에 두고 SF Symbol 만 morph 시켜 깜빡임 차단.
  private var playPauseButton: some View {
    Button(action: onPlayPause) {
      ZStack {
        Circle()
          .fill(.clear)
          .frame(width: 64, height: 64)
          .glassEffectCompatible(.regular, in: .circle)
        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
          .font(.system(size: 28, weight: .semibold))
          .foregroundStyle(.white)
          .contentTransition(.symbolEffect(.replace))
      }
      .frame(width: 64, height: 64)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(isPlaying ? "일시정지" : "재생")
    .accessibilityIdentifier("video_player_play_pause")
  }

  private func skipButton(delta: Double, systemName: String) -> some View {
    Button {
      onSkip(delta)
    } label: {
      Image(systemName: systemName)
        .font(.system(size: 22, weight: .regular))
        .foregroundStyle(.white)
        .frame(width: 48, height: 48)
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .glassEffectCompatible(.regularInteractive, in: .circle)
    .accessibilityLabel(delta < 0 ? "10초 뒤로" : "10초 앞으로")
  }

  // MARK: - Bottom

  private var bottomBar: some View {
    VStack(spacing: 8) {
      Spacer(minLength: 0)
      HStack(spacing: 8) {
        Text(VideoMetaFormatter.clock(current: currentTime, total: duration))
          .pretendard(.captionMeta)
          .foregroundStyle(.white)
        Spacer(minLength: 0)
        pipButton
        fullscreenButton
      }
      ScrubBar(
        width: width - 32,
        currentTime: currentTime,
        duration: duration,
        isScrubbing: isScrubbing,
        onChange: onScrubChange,
        onEnd: onScrubEnd
      )
    }
    .padding(.horizontal, 16)
    .padding(.bottom, 16)
  }

  private var fullscreenButton: some View {
    Button(action: onFullscreenToggle) {
      Image(systemName: isFullscreen
        ? "arrow.down.right.and.arrow.up.left"
        : "arrow.up.left.and.arrow.down.right")
        .font(.system(size: 16, weight: .regular))
        .foregroundStyle(.white)
        .frame(width: 36, height: 36)
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .glassEffectCompatible(.regularInteractive, in: .circle)
    .accessibilityLabel(isFullscreen ? "풀스크린 종료" : "풀스크린")
    .accessibilityIdentifier("video_player_fullscreen")
  }

  private func speedLabel(_ value: Float) -> String {
    String(format: "%.2gx", value)
  }
}

private struct ScrubBar: View {
  let width: CGFloat
  let currentTime: TimeInterval
  let duration: TimeInterval
  let isScrubbing: Bool
  let onChange: (TimeInterval) -> Void
  let onEnd: (TimeInterval) -> Void

  private let trackHeight: CGFloat = 5
  private let thumbDiameter: CGFloat = 14

  var body: some View {
    let progress = duration > 0 ? max(0, min(1, currentTime / duration)) : 0
    let filledWidth = max(0, width * progress)

    return ZStack(alignment: .leading) {
      Capsule()
        .fill(Color.white.opacity(0.25))
        .frame(height: trackHeight)
      Capsule()
        .fill(AppTheme.brightTurquoise)
        .frame(width: filledWidth, height: trackHeight)
      Circle()
        .fill(.white)
        .frame(width: thumbDiameter, height: thumbDiameter)
        .offset(x: filledWidth - thumbDiameter / 2)
        .animation(isScrubbing ? nil : .linear(duration: 0.15), value: filledWidth)
    }
    .frame(height: thumbDiameter)
    .contentShape(.rect)
    .gesture(
      DragGesture(minimumDistance: 0)
        .onChanged { value in
          guard duration > 0, width > 0 else { return }
          let ratio = max(0, min(1, value.location.x / width))
          onChange(duration * ratio)
        }
        .onEnded { value in
          guard duration > 0, width > 0 else { return }
          let ratio = max(0, min(1, value.location.x / width))
          onEnd(duration * ratio)
        }
    )
    .accessibilityIdentifier("video_player_scrub")
  }
}
