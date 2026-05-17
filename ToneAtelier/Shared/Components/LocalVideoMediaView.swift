//
//  LocalVideoMediaView.swift
//  ToneAtelier
//
//  Created by LCH on 5/18/26.
//

import AVFoundation
import AVKit
import Foundation
import OSLog
import SwiftUI

/// 로컬 비디오 `Data` 의 인라인 재생.
/// thumbnail 단계는 `LocalVideoThumbnailView` 를 재사용하고 탭 시 임시 파일을 통해 `AVPlayer` 가동.
struct LocalVideoMediaView: View {
  let id: UUID
  let data: Data
  let mimeType: String

  @State private var player: AVPlayer?
  @State private var temporaryURL: URL?
  @State private var isStarting = false

  var body: some View {
    ZStack {
      Color.clear

      if let player {
        VideoPlayer(player: player)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .clipped()
      } else {
        thumbnailLayer
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .clipped()
    .onDisappear { teardown() }
  }

  private var thumbnailLayer: some View {
    Button {
      Task { await startPlayback() }
    } label: {
      LocalVideoThumbnailView(id: id, data: data, mimeType: mimeType)
        .overlay {
          if isStarting {
            ProgressView()
              .progressViewStyle(.circular)
              .tint(.white.opacity(0.95))
          } else {
            Image(systemName: "play.fill")
              .font(AppTheme.symbol(size: 36, weight: .regular))
              .foregroundStyle(.white.opacity(0.9))
              .shadow(radius: 8)
          }
        }
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("영상 재생")
  }

  private func startPlayback() async {
    guard !isStarting, player == nil else { return }
    isStarting = true

    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("LocalVideoPlay-\(id.uuidString).\(fileExtension)")

    do {
      try data.write(to: url)
      let avPlayer = AVPlayer(url: url)
      avPlayer.actionAtItemEnd = .pause
      try Task.checkCancellation()
      await MainActor.run {
        temporaryURL = url
        player = avPlayer
        isStarting = false
        avPlayer.play()
      }
    } catch is CancellationError {
      await MainActor.run { isStarting = false }
    } catch {
      Logger.videoPlayer.notice(
        "local inline playback failed: \(error.localizedDescription, privacy: .private)"
      )
      await MainActor.run { isStarting = false }
    }
  }

  private func teardown() {
    player?.pause()
    player = nil
    isStarting = false
    if let temporaryURL {
      try? FileManager.default.removeItem(at: temporaryURL)
      self.temporaryURL = nil
    }
  }

  private var fileExtension: String {
    switch mimeType.lowercased() {
    case "video/quicktime": return "mov"
    case "video/mp4": return "mp4"
    case let value where value.contains("m4v"): return "m4v"
    default: return "mov"
    }
  }
}
