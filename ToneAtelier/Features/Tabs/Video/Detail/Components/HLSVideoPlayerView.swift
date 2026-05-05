//
//  HLSVideoPlayerView.swift
//  ToneAtelier
//
//  Created by Codex on 5/5/26.
//

import AVFoundation
import AVKit
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

  @State private var player: AVPlayer?
  @State private var timeObserverToken: Any?
  @State private var statusObserver: NSKeyValueObservation?
  @State private var lastStreamURL: URL?
  @State private var currentTime: TimeInterval = 0
  @State private var pendingResumeTime: CMTime = .zero

  var body: some View {
    ZStack {
      if let player {
        PlayerControllerHost(
          player: player,
          cueText: activeCue?.text,
          qualities: qualities,
          selectedQuality: selectedQuality,
          subtitles: subtitles,
          selectedSubtitle: selectedSubtitle,
          onQualitySelect: onQualitySelect,
          onSubtitleSelect: onSubtitleSelect
        )
        .background(AppTheme.blackTurquoise)
      } else {
        ChatImageView(
          path: posterPath,
          baseURL: nil,
          shape: .roundedRect(cornerRadius: 0),
          placeholder: .photo,
          contentMode: .fill
        )
        .overlay(
          ProgressView()
            .progressViewStyle(.circular)
            .tint(AppTheme.gray45)
        )
      }
    }
    .onChange(of: streamURL) { _, newValue in
      replaceURL(newValue)
    }
    .onChange(of: preferredPeakBitRate) { _, newValue in
      player?.currentItem?.preferredPeakBitRate = newValue
    }
    .onAppear {
      replaceURL(streamURL)
    }
    .onDisappear {
      teardown()
    }
  }

  // MARK: - Player lifecycle

  private var activeCue: SubtitleCue? {
    cues.first(where: { currentTime >= $0.start && currentTime <= $0.end })
  }

  private func replaceURL(_ url: URL) {
    guard lastStreamURL != url else { return }
    if lastStreamURL != nil, let current = player?.currentTime() {
      pendingResumeTime = current
    } else {
      pendingResumeTime = .zero
    }
    lastStreamURL = url

    teardownObserver()
    let item = AVPlayerItem(url: url)
    item.preferredPeakBitRate = preferredPeakBitRate
    if let existing = player {
      existing.replaceCurrentItem(with: item)
    } else {
      let new = AVPlayer(playerItem: item)
      new.automaticallyWaitsToMinimizeStalling = true
      player = new
    }
    attachObserver(item: item)

    Logger.videoPlayer.notice("HLS replaceURL host=\(url.host ?? "?", privacy: .public)")
  }

  private func attachObserver(item: AVPlayerItem) {
    guard let player else { return }
    let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
    timeObserverToken = player.addPeriodicTimeObserver(
      forInterval: interval,
      queue: .main
    ) { time in
      // teardown 직후 in-flight callback 이 ifLet warning 을 내는 race 차단.
      guard player.rate > 0, player.currentItem != nil else { return }
      let current = CMTimeGetSeconds(time)
      let duration = CMTimeGetSeconds(player.currentItem?.duration ?? .zero)
      let safeDuration = duration.isFinite ? duration : 0
      currentTime = current.isFinite ? current : 0
      onTimeUpdate(currentTime, safeDuration)
    }
    statusObserver = item.observe(\.status, options: [.new]) { observed, _ in
      switch observed.status {
      case .readyToPlay:
        Logger.videoPlayer.notice("HLS readyToPlay")
        resumeAndPlay(player: player)
      case .failed:
        let reason = observed.error?.localizedDescription ?? "unknown"
        Logger.videoPlayer.error("HLS item failed: \(reason, privacy: .public)")
      case .unknown:
        break
      @unknown default:
        break
      }
    }
  }

  private func resumeAndPlay(player: AVPlayer) {
    let resume = pendingResumeTime
    if resume.seconds > 0 {
      pendingResumeTime = .zero
      player.seek(to: resume, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
        player.play()
      }
    } else {
      player.play()
    }
  }

  private func teardownObserver() {
    if let token = timeObserverToken {
      player?.removeTimeObserver(token)
      timeObserverToken = nil
    }
    statusObserver?.invalidate()
    statusObserver = nil
  }

  private func teardown() {
    teardownObserver()
    player?.pause()
    player?.replaceCurrentItem(with: nil)
    player = nil
    Logger.videoPlayer.notice("HLS teardown")
  }
}

// MARK: - AVPlayerViewController 호스팅 + 자막 overlay

private struct PlayerControllerHost: UIViewControllerRepresentable {
  let player: AVPlayer
  let cueText: String?
  let qualities: [StreamQualityDTO]
  let selectedQuality: String?
  let subtitles: [StreamSubtitleDTO]
  let selectedSubtitle: StreamSubtitleDTO?
  let onQualitySelect: (String?) -> Void
  let onSubtitleSelect: (StreamSubtitleDTO?) -> Void

  func makeUIViewController(context: Context) -> AVPlayerViewController {
    let controller = AVPlayerViewController()
    controller.player = player
    controller.showsPlaybackControls = true
    controller.allowsPictureInPicturePlayback = true
    controller.videoGravity = .resizeAspect
    context.coordinator.installSubtitleLabel(into: controller.contentOverlayView)
    rebuildTransportMenu(controller: controller)
    return controller
  }

  func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
    if controller.player !== player {
      controller.player = player
    }
    context.coordinator.update(text: cueText)
    rebuildTransportMenu(controller: controller)
  }

  private func rebuildTransportMenu(controller: AVPlayerViewController) {
    var items: [UIMenuElement] = []

    var qualityChildren: [UIMenuElement] = [
      UIAction(
        title: "자동",
        state: selectedQuality == nil ? .on : .off,
        handler: { _ in onQualitySelect(nil) }
      )
    ]
    qualityChildren += qualities.map { item in
      UIAction(
        title: item.quality,
        state: selectedQuality == item.quality ? .on : .off,
        handler: { _ in onQualitySelect(item.quality) }
      )
    }
    items.append(UIMenu(
      title: "화질",
      image: UIImage(systemName: "rectangle.stack"),
      children: qualityChildren
    ))

    if !subtitles.isEmpty {
      var subtitleChildren: [UIMenuElement] = [
        UIAction(
          title: "자막 끄기",
          state: selectedSubtitle == nil ? .on : .off,
          handler: { _ in onSubtitleSelect(nil) }
        )
      ]
      subtitleChildren += subtitles.map { sub in
        UIAction(
          title: sub.name,
          state: selectedSubtitle?.language == sub.language ? .on : .off,
          handler: { _ in onSubtitleSelect(sub) }
        )
      }
      items.append(UIMenu(
        title: "자막",
        image: UIImage(systemName: "captions.bubble"),
        children: subtitleChildren
      ))
    }

//    controller.transportBarCustomMenuItems = items
  }

  func makeCoordinator() -> Coordinator { Coordinator() }

  final class Coordinator {
    private weak var subtitleLabel: UILabel?
    private weak var subtitleBackground: UIView?

    func installSubtitleLabel(into overlay: UIView?) {
      guard let overlay, subtitleLabel == nil else { return }
      let background = UIView()
      background.backgroundColor = UIColor.black.withAlphaComponent(0.55)
      background.layer.cornerRadius = 8
      background.layer.masksToBounds = true
      background.translatesAutoresizingMaskIntoConstraints = false
      background.isHidden = true
      background.isUserInteractionEnabled = false

      let label = UILabel()
      label.font = UIFont(name: "Pretendard-Bold", size: 13) ?? .boldSystemFont(ofSize: 13)
      label.textColor = .white
      label.textAlignment = .center
      label.numberOfLines = 0
      label.translatesAutoresizingMaskIntoConstraints = false

      overlay.addSubview(background)
      background.addSubview(label)
      NSLayoutConstraint.activate([
        background.bottomAnchor.constraint(equalTo: overlay.bottomAnchor, constant: -56),
        background.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
        background.leadingAnchor.constraint(greaterThanOrEqualTo: overlay.leadingAnchor, constant: 16),
        background.trailingAnchor.constraint(lessThanOrEqualTo: overlay.trailingAnchor, constant: -16),
        label.topAnchor.constraint(equalTo: background.topAnchor, constant: 6),
        label.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -6),
        label.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 12),
        label.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -12)
      ])

      subtitleLabel = label
      subtitleBackground = background
    }

    func update(text: String?) {
      guard let label = subtitleLabel, let background = subtitleBackground else { return }
      if let text, !text.isEmpty {
        label.text = text
        background.isHidden = false
      } else {
        background.isHidden = true
      }
    }
  }
}
