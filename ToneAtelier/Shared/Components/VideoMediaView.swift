//
//  VideoMediaView.swift
//  ToneAtelier
//
//  Created by Codex on 5/4/26.
//

import AVFoundation
import AVKit
import ComposableArchitecture
import OSLog
import SwiftUI
import UIKit

struct VideoMediaView: View {
  let path: String
  let shape: ChatImageShape
  let contentMode: ContentMode
  /// false 면 thumbnail 자체가 tap 을 흡수하지 않고 부모(예: 게시글 셀)가 tap 을 받도록 함.
  /// list cell 에서는 cell 클릭 = detail 진입이라 인라인 재생을 비활성한다.
  let inlinePlaybackEnabled: Bool
  let canReceiveTransfer: Bool

  init(
    path: String,
    shape: ChatImageShape = .roundedRect(cornerRadius: 0),
    contentMode: ContentMode = .fill,
    inlinePlaybackEnabled: Bool = true,
    canReceiveTransfer: Bool = false
  ) {
    self.path = path
    self.shape = shape
    self.contentMode = contentMode
    self.inlinePlaybackEnabled = inlinePlaybackEnabled
    self.canReceiveTransfer = canReceiveTransfer
  }

  @Dependency(\.commonClient) private var commonClient
  @Dependency(\.sessionClient) private var sessionClient

  @StateObject private var coordinator = InlineVideoCoordinator.shared
  @State private var playerHolder = VideoPlayerHolder()
  @State private var instanceID = UUID()
  @State private var isStarting = false
  @State private var streamURL: URL?
  @State private var isPlayingActive = false
  @State private var isFullscreen = false
  @State private var assetLoader: AuthenticatedAssetLoader?

  var body: some View {
    ZStack {
      // VideoPlayer가 자연 사이즈로 ZStack을 부풀리는 걸 막는 앵커.
      Color.clear

      if isPlayingActive, let streamURL {
        HLSVideoPlayerView(
          streamURL: streamURL,
          cues: [],
          posterPath: path,
          preferredPeakBitRate: 0,
          qualities: [],
          selectedQuality: nil,
          subtitles: [],
          selectedSubtitle: nil,
          initialResumeTime: nil,
          onQualitySelect: { _ in },
          onSubtitleSelect: { _ in },
          onTimeUpdate: { _, _ in },
          isFullscreen: isFullscreen,
          onFullscreenToggle: {
            isFullscreen = true
          },
          holder: playerHolder
        )
      } else {
        thumbnailLayer
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .clipped()
    .clipShape(shape.shape)
    .onChange(of: coordinator.activeID) { _, newValue in
      if isPlayingActive, newValue != instanceID {
        if InlineVideoCoordinator.shared.activePath == path {
          localReset()
        } else {
          teardown()
        }
      }
    }
    .onAppear {
      if canReceiveTransfer {
        checkTransfer()
      }
    }
    .onDisappear {
      // fullscreen modal이 위에 덮일 때도 onDisappear가 fire되므로 그 케이스는 player를 살려둠.
      if !isFullscreen {
        if coordinator.activeID == instanceID {
          teardown()
        } else {
          localReset()
        }
      }
    }
    .fullScreenCover(isPresented: $isFullscreen) {
      if let streamURL {
        HLSVideoPlayerView(
          streamURL: streamURL,
          cues: [],
          posterPath: path,
          preferredPeakBitRate: 0,
          qualities: [],
          selectedQuality: nil,
          subtitles: [],
          selectedSubtitle: nil,
          initialResumeTime: nil,
          onQualitySelect: { _ in },
          onSubtitleSelect: { _ in },
          onTimeUpdate: { _, _ in },
          isFullscreen: true,
          onFullscreenToggle: {
            isFullscreen = false
          },
          holder: playerHolder
        )
        .ignoresSafeArea()
        .background(Color.black)
        .onAppear {
          applyFullscreenOrientation(true)
        }
        .onDisappear {
          applyFullscreenOrientation(false)
        }
      }
    }
  }

  // MARK: - Thumbnail layer

  // 부모 Button 안에서도 탭이 outer로 전파되지 않도록 inner Button 사용.
  // inlinePlaybackEnabled=false 인 경우 (list cell 등) thumbnail 만 표시하고 tap 은 부모로 전파.
  @ViewBuilder
  private var thumbnailLayer: some View {
    if inlinePlaybackEnabled {
      ZStack {
        VideoThumbnailView(path: path, contentMode: contentMode)
          .contentShape(.rect)

        Button {
          Task { await startPlayback() }
        } label: {
          ZStack {
            if isStarting {
              ProgressView()
                .progressViewStyle(.circular)
                .tint(.white.opacity(0.95))
            } else {
              Image(systemName: "play.circle.fill")
                .font(AppTheme.symbol(size: 44, weight: .regular))
                .foregroundStyle(.white.opacity(0.95))
            }
          }
          .frame(width: 80, height: 80)
          .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("영상 재생")
      }
    } else {
      VideoThumbnailView(path: path, contentMode: contentMode)
        .overlay {
          Image(systemName: "play.circle.fill")
            .font(AppTheme.symbol(size: 44, weight: .regular))
            .foregroundStyle(.white.opacity(0.95))
        }
        .allowsHitTesting(false)
    }
  }

  // MARK: - Playback control

  private func checkTransfer() {
    if InlineVideoCoordinator.shared.activePath == path,
       let sharedHolder = InlineVideoCoordinator.shared.activeHolder,
       let sharedURL = InlineVideoCoordinator.shared.activeStreamURL {
      self.playerHolder = sharedHolder
      self.assetLoader = InlineVideoCoordinator.shared.activeLoader
      self.streamURL = sharedURL
      self.isPlayingActive = true
      InlineVideoCoordinator.shared.claim(
        instanceID,
        path: path,
        holder: sharedHolder,
        loader: InlineVideoCoordinator.shared.activeLoader,
        streamURL: sharedURL
      )
    }
  }

  private func startPlayback() async {
    guard !isStarting, !isPlayingActive else { return }
    isStarting = true

    var firstError: Error?
    for attempt in 0..<2 {
      do {
        if attempt > 0 {
          Logger.videoPlayer.notice("inline retry attempt=\(attempt, privacy: .public)")
          try await Task.sleep(nanoseconds: 300_000_000)
        }
        let (avPlayerItem, loader, requestURL) = try await performStartAttempt()
        try Task.checkCancellation()
        await MainActor.run {
          isStarting = false
          assetLoader = loader
          streamURL = requestURL
          playerHolder.replaceCurrentItem(with: avPlayerItem, url: requestURL)
          isPlayingActive = true
          coordinator.claim(
            instanceID,
            path: path,
            holder: playerHolder,
            loader: loader,
            streamURL: requestURL
          )
        }
        return
      } catch is CancellationError {
        await MainActor.run {
          isStarting = false
        }
        return
      } catch {
        if firstError == nil { firstError = error }
        continue
      }
    }

    if let firstError {
      let nsError = firstError as NSError
      Logger.videoPlayer.error("""
        inline start failed after retry — \
        domain=\(nsError.domain, privacy: .public) \
        code=\(nsError.code, privacy: .public) \
        message=\(firstError.localizedDescription, privacy: .private)
        """)
    }
    await MainActor.run {
      isStarting = false
    }
  }

  private func performStartAttempt() async throws -> (AVPlayerItem, AuthenticatedAssetLoader, URL) {
    let request = try await commonClient.makeVideoRequest(path)
    Logger.videoPlayer.notice(
      "inline streaming attempt — path=\(request.url.path, privacy: .private)"
    )
    let loader = AuthenticatedAssetLoader(sessionClient: sessionClient)
    let customURL = AuthenticatedAssetLoader.customURL(from: request.url)
    let asset = AVURLAsset(url: customURL)
    asset.resourceLoader.setDelegate(loader, queue: loader.delegateQueue)
    let (tracks, duration) = try await asset.load(.tracks, .duration)
    let durationOK = duration.isIndefinite || duration.seconds > 0
    guard !tracks.isEmpty, durationOK else {
      throw NSError(
        domain: "VideoMediaView",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: "asset not ready tracks=\(tracks.count) duration=\(duration.seconds)"]
      )
    }
    Logger.videoPlayer.notice("inline streaming ready — playback starting")
    let item = AVPlayerItem(asset: asset)
    return (item, loader, request.url)
  }

  private func applyFullscreenOrientation(_ newValue: Bool) {
    let scene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first
    let rootVC = scene?.keyWindow?.rootViewController
    if newValue {
      AppDelegate.supportedOrientations = .allButUpsideDown
      rootVC?.setNeedsUpdateOfSupportedInterfaceOrientations()
      scene?.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
    } else {
      AppDelegate.supportedOrientations = .portrait
      rootVC?.setNeedsUpdateOfSupportedInterfaceOrientations()
      scene?.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
    }
  }

  private func localReset() {
    isPlayingActive = false
    streamURL = nil
    assetLoader = nil
    isStarting = false
  }

  private func teardown() {
    playerHolder.teardown()
    localReset()
    coordinator.release(instanceID)
  }
}
