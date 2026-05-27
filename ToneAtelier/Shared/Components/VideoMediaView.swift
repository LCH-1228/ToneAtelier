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

  init(
    path: String,
    shape: ChatImageShape = .roundedRect(cornerRadius: 0),
    contentMode: ContentMode = .fill,
    inlinePlaybackEnabled: Bool = true
  ) {
    self.path = path
    self.shape = shape
    self.contentMode = contentMode
    self.inlinePlaybackEnabled = inlinePlaybackEnabled
  }

  @Dependency(\.commonClient) private var commonClient
  @Dependency(\.sessionClient) private var sessionClient

  @StateObject private var coordinator = InlineVideoCoordinator.shared
  @State private var instanceID = UUID()
  @State private var isStarting = false
  @State private var player: AVPlayer?
  @State private var assetLoader: AuthenticatedAssetLoader?
  @State private var isPresentingFullscreen = false

  var body: some View {
    ZStack {
      // VideoPlayer가 자연 사이즈로 ZStack을 부풀리는 걸 막는 앵커.
      Color.clear

      if let player {
        VideoPlayer(player: player)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .clipped()
          .overlay(alignment: .bottomTrailing) {
            fullscreenButton
          }
      } else {
        thumbnailLayer
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .clipped()
    .clipShape(shape.shape)
    .onChange(of: coordinator.activeID) { _, newValue in
      if player != nil, newValue != instanceID {
        teardown()
      }
    }
    .onDisappear {
      // fullscreen modal이 위에 덮일 때도 onDisappear가 fire되므로 그 케이스는 player를 살려둠.
      // 살려두지 않으면 dismiss 후 thumbnail 회귀 + 재탭 시 makeVideoRequest 재호출 → 세션 재조회.
      if !isPresentingFullscreen {
        teardown()
      }
    }
  }

  // MARK: - Thumbnail layer

  // 부모 Button 안에서도 탭이 outer로 전파되지 않도록 inner Button 사용.
  // inlinePlaybackEnabled=false 인 경우 (list cell 등) thumbnail 만 표시하고 tap 은 부모로 전파.
  @ViewBuilder
  private var thumbnailLayer: some View {
    if inlinePlaybackEnabled {
      Button {
        Task { await startPlayback() }
      } label: {
        thumbnailContent
      }
      .buttonStyle(.plain)
      .accessibilityLabel("영상 재생")
    } else {
      thumbnailContent
        .allowsHitTesting(false)
    }
  }

  private var thumbnailContent: some View {
    VideoThumbnailView(path: path, contentMode: contentMode)
      .overlay {
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
      .contentShape(.rect)
  }

  // MARK: - Fullscreen button

  private var fullscreenButton: some View {
    Button {
      enterFullscreen()
    } label: {
      Image(systemName: "arrow.up.left.and.arrow.down.right")
        .font(AppTheme.symbol(size: 14, weight: .semibold))
        .foregroundStyle(.white)
        .frame(width: 32, height: 32)
        .background(Color.black.opacity(0.55))
        .clipShape(Circle())
    }
    .buttonStyle(.plain)
    .padding(.bottom, 56)
    .padding(.trailing, 12)
    .accessibilityLabel("전체보기")
  }

  // MARK: - Playback control

  private func startPlayback() async {
    guard !isStarting, player == nil else { return }
    coordinator.claim(instanceID)
    isStarting = true

    var firstError: Error?
    for attempt in 0..<2 {
      do {
        if attempt > 0 {
          Logger.videoPlayer.notice("inline retry attempt=\(attempt, privacy: .public)")
          try await Task.sleep(nanoseconds: 300_000_000)
        }
        let (avPlayer, loader) = try await performStartAttempt()
        try Task.checkCancellation()
        await MainActor.run {
          guard coordinator.activeID == instanceID else {
            isStarting = false
            return
          }
          isStarting = false
          assetLoader = loader
          player = avPlayer
          avPlayer.play()
        }
        return
      } catch is CancellationError {
        await MainActor.run {
          isStarting = false
          coordinator.release(instanceID)
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
      coordinator.release(instanceID)
    }
  }

  private func performStartAttempt() async throws -> (AVPlayer, AuthenticatedAssetLoader) {
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
    let avPlayer = AVPlayer(playerItem: item)
    avPlayer.actionAtItemEnd = .pause
    return (avPlayer, loader)
  }

  @MainActor
  private func enterFullscreen() {
    guard let player else { return }
    Logger.videoPlayer.notice("inline → AVPlayerViewController fullscreen presented")

    let controller = DismissNotifyingPlayerController()
    controller.player = player
    controller.modalPresentationStyle = .fullScreen
    controller.onDismiss = {
      Task { @MainActor in
        isPresentingFullscreen = false
      }
    }

    guard
      let scene = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .first(where: { $0.activationState == .foregroundActive }),
      let keyWindow = scene.windows.first(where: \.isKeyWindow) ?? scene.windows.first,
      let rootVC = keyWindow.rootViewController
    else {
      return
    }

    var topVC = rootVC
    while let presented = topVC.presentedViewController {
      topVC = presented
    }

    isPresentingFullscreen = true
    // 전환 중 AVKit이 player를 잠시 멈추므로 presentation 완료 후 재개.
    topVC.present(controller, animated: true) {
      player.play()
    }
  }

  private func teardown() {
    player?.pause()
    player = nil
    assetLoader = nil
    isStarting = false
    coordinator.release(instanceID)
  }
}

private final class DismissNotifyingPlayerController: AVPlayerViewController {
  var onDismiss: (() -> Void)?

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    if isBeingDismissed {
      onDismiss?()
    }
  }
}
