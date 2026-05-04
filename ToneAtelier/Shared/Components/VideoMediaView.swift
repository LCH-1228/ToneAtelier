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

  init(
    path: String,
    shape: ChatImageShape = .roundedRect(cornerRadius: 0),
    contentMode: ContentMode = .fill
  ) {
    self.path = path
    self.shape = shape
    self.contentMode = contentMode
  }

  @Dependency(\.commonClient) private var commonClient

  @StateObject private var coordinator = InlineVideoCoordinator.shared
  @State private var instanceID = UUID()
  @State private var isStarting = false
  @State private var player: AVPlayer?
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
  private var thumbnailLayer: some View {
    Button {
      Task { await startPlayback() }
    } label: {
      VideoThumbnailView(path: path, contentMode: contentMode)
        .overlay(alignment: .topLeading) {
          videoBadge.padding(12)
        }
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
    .buttonStyle(.plain)
    .accessibilityLabel("영상 재생")
  }

  private var videoBadge: some View {
    Text("영상")
      .pretendard(.captionMeta)
      .foregroundStyle(AppTheme.gray15)
      .padding(.horizontal, 8)
      .frame(height: 22)
      .background(AppTheme.deepTurquoise.opacity(0.85))
      .clipShape(Capsule())
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

    do {
      let request = try await commonClient.makeVideoRequest(path)
      let asset = AVURLAsset(
        url: request.url,
        options: ["AVURLAssetHTTPHeaderFieldsKey": request.headers]
      )
      let item = AVPlayerItem(asset: asset)
      let avPlayer = AVPlayer(playerItem: item)
      avPlayer.actionAtItemEnd = .pause
      try Task.checkCancellation()
      await MainActor.run {
        guard coordinator.activeID == instanceID else {
          isStarting = false
          return
        }
        isStarting = false
        player = avPlayer
        avPlayer.play()
      }
    } catch is CancellationError {
      await MainActor.run { isStarting = false }
    } catch {
      Logger.videoPlayer.notice(
        "inline start failed: \(error.localizedDescription, privacy: .private)"
      )
      await MainActor.run {
        isStarting = false
        coordinator.release(instanceID)
      }
    }
  }

  @MainActor
  private func enterFullscreen() {
    guard let player else { return }

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
