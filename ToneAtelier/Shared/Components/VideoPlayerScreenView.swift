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

/// 풀스크린 영상 viewer.
///
/// 재생 전략
/// - 1차(스트리밍): `commonClient.makeVideoRequest`로 인증 헤더 부착 URLRequest를 받고
///   `AVURLAsset(url:options:)`의 `AVURLAssetHTTPHeaderFieldsKey`에 동일 헤더를 실어 progressive
///   download(byte-range) 재생을 시도. 자산 로드에서 throw 하거나 `isPlayable == false`면 fallback.
/// - 2차(다운로드 fallback): `commonClient.fetchVideo`로 전체 바이트를 받아 임시 파일에 쓰고
///   로컬 URL `AVPlayer`로 재생. 한 번에 한해 분기되며 재생 도중 `AVPlayerItem.status == .failed`로
///   떨어지면 1차 player를 정리한 뒤 이 경로로 전환.
struct VideoPlayerScreenView: View {
  let path: String
  let onClose: () -> Void

  @Dependency(\.commonClient) private var commonClient

  @State private var player: AVPlayer?
  @State private var hasFailed = false
  @State private var temporaryURL: URL?

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      content

      closeButtonOverlay
    }
    .task(id: path) {
      await prepare()
    }
    .onDisappear {
      teardown()
    }
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
          .font(AppTheme.pretendard(size: 13, weight: .medium))
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
    } else {
      await fallbackToDownload()
    }
  }

  /// 1차 스트리밍 시도. 자산 로드 단계에서 throw 하거나 `isPlayable == false`면 false 반환.
  private func tryStreaming() async -> Bool {
    do {
      let request = try await commonClient.makeVideoRequest(path)
      Logger.videoPlayer.notice(
        "streaming attempt — path=\(request.url.path, privacy: .private)"
      )
      let asset = AVURLAsset(
        url: request.url,
        options: ["AVURLAssetHTTPHeaderFieldsKey": request.headers]
      )
      let playable = try await asset.load(.isPlayable)
      guard playable else {
        Logger.videoPlayer.notice("streaming asset not playable")
        return false
      }
      Logger.videoPlayer.notice("streaming ready — playback starting")
      let item = AVPlayerItem(asset: asset)
      let avPlayer = AVPlayer(playerItem: item)
      avPlayer.actionAtItemEnd = .pause
      await MainActor.run {
        player = avPlayer
        avPlayer.play()
      }
      return true
    } catch is CancellationError {
      return false
    } catch {
      Logger.videoPlayer.notice(
        "streaming load failed: \(error.localizedDescription, privacy: .private)"
      )
      return false
    }
  }

  /// 재생 도중 `.failed` 관측 시 true. task 취소/정상 종료 시 false.
  private func observeRuntimeFailure() async -> Bool {
    let item = await MainActor.run { player?.currentItem }
    guard let item else { return false }
    for await status in item.publisher(for: \.status).values {
      if status == .failed {
        Logger.videoPlayer.notice("runtime .failed — falling back to download")
        await MainActor.run {
          player?.pause()
          player = nil
        }
        return true
      }
    }
    return false
  }

  /// 2차 다운로드 fallback. 전체 바이트를 받아 임시 파일에 쓰고 로컬 URL로 재생.
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
      await MainActor.run {
        temporaryURL = tempURL
        player = avPlayer
        avPlayer.play()
      }
    } catch is CancellationError {
      // 화면 사라짐
    } catch {
      Logger.videoPlayer.notice(
        "fallback download failed: \(error.localizedDescription, privacy: .private)"
      )
      await MainActor.run {
        hasFailed = true
      }
    }
  }

  private func teardown() {
    player?.pause()
    player = nil
    if let temporaryURL {
      try? FileManager.default.removeItem(at: temporaryURL)
      self.temporaryURL = nil
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

  // MARK: - Close button

  private var closeButtonOverlay: some View {
    VStack {
      HStack {
        Button(action: onClose) {
          Image(systemName: "xmark")
            .font(AppTheme.symbol(size: 18, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(Color.black.opacity(0.45))
            .clipShape(Circle())
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("닫기")
        .padding(.leading, 12)
        .padding(.top, 8)

        Spacer(minLength: 0)
      }

      Spacer(minLength: 0)
    }
  }
}
