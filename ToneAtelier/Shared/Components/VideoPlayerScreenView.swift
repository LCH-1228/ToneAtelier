//
//  VideoPlayerScreenView.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//

import AVKit
import Combine
import ComposableArchitecture
import OSLog
import SwiftUI

// 1차 스트리밍 실패 시 전체 다운로드로 fallback.
struct VideoPlayerScreenView: View {
  let path: String
  let initialSeconds: Double
  let onTimeUpdate: ((Double) -> Void)?
  let onClose: () -> Void

  init(
    path: String,
    initialSeconds: Double = 0,
    onTimeUpdate: ((Double) -> Void)? = nil,
    onClose: @escaping () -> Void
  ) {
    self.path = path
    self.initialSeconds = initialSeconds
    self.onTimeUpdate = onTimeUpdate
    self.onClose = onClose
  }

  @Dependency(\.commonClient) private var commonClient
  @Dependency(\.sessionClient) private var sessionClient

  @State private var player: AVPlayer?
  @State private var assetLoader: AuthenticatedAssetLoader?
  @State private var hasFailed = false
  @State private var temporaryURL: URL?
  @State private var timeObserverToken: Any?

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      content
    }
    .task(id: path) {
      await prepare()
    }
    .onDisappear {
      teardown()
    }
    .simultaneousGesture(
      DragGesture(minimumDistance: 30)
        .onEnded { value in
          // 세로 dominant + 충분한 거리만 dismiss로 인정 → AVKit 스크러버(가로 우세)와 충돌 회피.
          if value.translation.height > 120, abs(value.translation.width) < 80 {
            onClose()
          }
        }
    )
  }

  // MARK: - Content

  @ViewBuilder
  private var content: some View {
    if let player {
      VideoPlayer(player: player)
        .ignoresSafeArea()
    } else if hasFailed {
      VStack(spacing: 8) {
        Image(systemName: "exclamationmark.triangle")
          .font(AppTheme.symbol(size: 28, weight: .regular))
          .foregroundStyle(.white.opacity(0.8))
        Text("영상을 불러오지 못했어요.")
          .pretendard(.body3)
          .foregroundStyle(.white.opacity(0.8))
      }
    } else {
      ProgressView()
        .progressViewStyle(.circular)
        .tint(.white.opacity(0.8))
    }
  }

  // MARK: - Player lifecycle

  private func prepare() async {
    if await tryStreaming() {
      if await observeRuntimeFailure() {
        await fallbackToDownload()
      }
      return
    }
    // 첫 시도 실패 시 토큰 갱신이 그 사이 일어났을 수 있으므로 1회 retry.
    Logger.videoPlayer.notice("streaming retry attempt=1")
    try? await Task.sleep(nanoseconds: 300_000_000)
    if await tryStreaming() {
      if await observeRuntimeFailure() {
        await fallbackToDownload()
      }
      return
    }
    await fallbackToDownload()
  }

  private func tryStreaming() async -> Bool {
    do {
      let request = try await commonClient.makeVideoRequest(path)
      Logger.videoPlayer.notice(
        "streaming attempt — path=\(request.url.path, privacy: .private)"
      )
      let loader = AuthenticatedAssetLoader(sessionClient: sessionClient)
      let customURL = AuthenticatedAssetLoader.customURL(from: request.url)
      let asset = AVURLAsset(url: customURL)
      asset.resourceLoader.setDelegate(loader, queue: loader.delegateQueue)
      let (tracks, duration) = try await asset.load(.tracks, .duration)
      let durationOK = duration.isIndefinite || duration.seconds > 0
      guard !tracks.isEmpty, durationOK else {
        Logger.videoPlayer.error("""
          streaming asset not ready — \
          tracks=\(tracks.count, privacy: .public) \
          duration=\(duration.seconds, privacy: .public)
          """)
        return false
      }
      Logger.videoPlayer.notice("streaming ready — playback starting")
      let item = AVPlayerItem(asset: asset)
      let avPlayer = AVPlayer(playerItem: item)
      avPlayer.actionAtItemEnd = .pause
      await seekIfNeeded(avPlayer)
      await MainActor.run {
        attachTimeObserver(to: avPlayer)
        assetLoader = loader
        player = avPlayer
        avPlayer.play()
      }
      return true
    } catch is CancellationError {
      return false
    } catch {
      let nsError = error as NSError
      Logger.videoPlayer.error("""
        streaming load failed — \
        domain=\(nsError.domain, privacy: .public) \
        code=\(nsError.code, privacy: .public) \
        message=\(error.localizedDescription, privacy: .private)
        """)
      return false
    }
  }

  private func observeRuntimeFailure() async -> Bool {
    let item = await MainActor.run { player?.currentItem }
    guard let item else { return false }
    for await status in item.publisher(for: \.status).values where status == .failed {
      let err = item.error as NSError?
      Logger.videoPlayer.error("""
        runtime .failed — \
        domain=\(err?.domain ?? "?", privacy: .public) \
        code=\(err?.code ?? -1, privacy: .public) \
        — falling back to download
        """)
      await MainActor.run {
        player?.pause()
        player = nil
      }
      return true
    }
    return false
  }

  private func fallbackToDownload() async {
    do {
      let data = try await commonClient.fetchVideo(path)
      let tempURL = makeTemporaryURL()
      try data.write(to: tempURL)
      let avPlayer = AVPlayer(url: tempURL)
      avPlayer.actionAtItemEnd = .pause
      Logger.videoPlayer.notice(
        "fallback download playing — bytes=\(data.count, privacy: .public) temp=\(tempURL.path, privacy: .private)"
      )
      await seekIfNeeded(avPlayer)
      await MainActor.run {
        attachTimeObserver(to: avPlayer)
        temporaryURL = tempURL
        player = avPlayer
        avPlayer.play()
      }
    } catch is CancellationError {
    } catch {
      let nsError = error as NSError
      Logger.videoPlayer.error("""
        fallback download failed — \
        domain=\(nsError.domain, privacy: .public) \
        code=\(nsError.code, privacy: .public) \
        message=\(error.localizedDescription, privacy: .private)
        """)
      await MainActor.run {
        hasFailed = true
      }
    }
  }

  private func teardown() {
    detachTimeObserver()
    player?.pause()
    player = nil
    assetLoader = nil
    if let temporaryURL {
      try? FileManager.default.removeItem(at: temporaryURL)
      self.temporaryURL = nil
    }
  }

  /// `initialSeconds`가 의미 있을 때만 seek. AVPlayer 생성 직후 한 번 호출되어 첫 publish 위치를 보정.
  private func seekIfNeeded(_ avPlayer: AVPlayer) async {
    guard initialSeconds > 0 else { return }
    let target = CMTime(seconds: initialSeconds, preferredTimescale: 600)
    await avPlayer.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
  }

  /// 0.25s 간격 시간 옵저버. inline 동기화용. `onTimeUpdate`가 nil이면 부착하지 않음.
  private func attachTimeObserver(to avPlayer: AVPlayer) {
    guard let onTimeUpdate else { return }
    let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
    timeObserverToken = avPlayer.addPeriodicTimeObserver(
      forInterval: interval,
      queue: .main
    ) { time in
      let seconds = time.seconds
      guard !seconds.isNaN, seconds.isFinite else { return }
      onTimeUpdate(seconds)
    }
  }

  private func detachTimeObserver() {
    if let token = timeObserverToken {
      player?.removeTimeObserver(token)
      timeObserverToken = nil
    }
  }

  /// 임시 파일 URL. 가능하면 원본 확장자를 유지(AVPlayer가 컨테이너 추정에 사용), 아니면 mp4로 fallback.
  private func makeTemporaryURL() -> URL {
    let originalExt = (path as NSString).pathExtension
    let isSafe = !originalExt.isEmpty && originalExt.allSatisfy(\.isASCII)
    let ext = isSafe ? originalExt : "mp4"
    return FileManager.default.temporaryDirectory
      .appendingPathComponent("ToneAtelier-video-\(UUID().uuidString).\(ext)")
  }

}
