//
//  VideoPlayerScreenView.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//

import AVKit
import ComposableArchitecture
import SwiftUI

/// 풀스크린 영상 viewer. AVKit `VideoPlayer`로 단순 재생.
///
/// 동작
/// - `onAppear`에서 player 생성 후 즉시 `play()`.
/// - 절대 URL이면 `AVPlayer(url:)`로 직접, 아니면 `sessionClient` baseURL과 결합 후 재생.
///   첨부 영상 path는 인증 보호되어 있으나 `AVPlayer`에 헤더 부착이 표준이 아니라 1차 단순화로
///   baseURL 결합만 수행한다. 인증 토큰 부착이 필요한 백엔드라면 `AVURLAsset` resourceLoader로
///   재구성해야 하며 후속 작업으로 분리.
/// - `onDisappear`에서 `pause()` + player 해제로 재생 잔여를 차단.
/// - 좌상단 닫기 버튼.
struct VideoPlayerScreenView: View {
  let path: String
  let onClose: () -> Void

  @Dependency(\.sessionClient) private var sessionClient

  @State private var player: AVPlayer?
  @State private var resolvedURL: URL?
  @State private var hasFailed = false

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
    let url = await resolveURL(for: path)
    guard let url else {
      await MainActor.run {
        hasFailed = true
      }
      return
    }
    await MainActor.run {
      resolvedURL = url
      let avPlayer = AVPlayer(url: url)
      avPlayer.actionAtItemEnd = .pause
      player = avPlayer
      avPlayer.play()
    }
  }

  private func teardown() {
    player?.pause()
    player = nil
  }

  // MARK: - URL resolution

  /// 절대 URL이면 그대로 사용. 그렇지 않으면 sessionClient baseURL과 결합한다.
  /// `CommonRouter.fetchPhoto`처럼 인증 토큰 부착이 필요한 경로라도 1차 구현은 단순 결합으로 둔다.
  private func resolveURL(for raw: String) async -> URL? {
    if let direct = URL(string: raw), direct.scheme != nil {
      return direct
    }
    let snapshot = await sessionClient.snapshot()
    let base = snapshot.configuration.baseURL
    let trimmedPath = raw.hasPrefix("/") ? String(raw.dropFirst()) : raw
    return URL(string: trimmedPath, relativeTo: base)?.absoluteURL
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
