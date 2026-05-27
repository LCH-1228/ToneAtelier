//
//  VideoThumbnailView.swift
//  ToneAtelier
//
//  Created by Codex on 5/4/26.
//

import AVFoundation
import ComposableArchitecture
import OSLog
import SwiftUI
import UIKit

struct VideoThumbnailView: View {
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

  @State private var image: UIImage?
  @State private var isLoading = false
  @State private var hasFailed = false

  var body: some View {
    contentLayer
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .clipped()
      .clipShape(shape.shape)
      .task(id: path) {
        await load()
      }
  }

  // MARK: - Layers

  @ViewBuilder
  private var contentLayer: some View {
    if let image {
      Image(uiImage: image)
        .resizable()
        .aspectRatio(contentMode: contentMode)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    } else if isLoading {
      ZStack {
        placeholderLayer
        ProgressView()
          .progressViewStyle(.circular)
          .tint(AppTheme.gray45)
      }
    } else if hasFailed {
      placeholderLayer
    } else {
      placeholderLayer
    }
  }

  private var placeholderLayer: some View {
    ZStack {
      AppTheme.blackTurquoise
      Image(systemName: "video")
        .foregroundStyle(AppTheme.gray60)
    }
  }

  // MARK: - Loading

  private var cacheKey: String { "video-thumb:\(path)" }

  private func load() async {
    guard !path.isEmpty else {
      image = nil
      isLoading = false
      hasFailed = false
      return
    }

    if let cached = await ChatImageDecodedCache.shared.image(for: cacheKey) {
      image = cached
      isLoading = false
      hasFailed = false
      return
    }

    image = nil
    isLoading = true
    hasFailed = false

    guard await VideoThumbnailLimiter.shared.acquire() else {
      isLoading = false
      return
    }
    defer { Task { await VideoThumbnailLimiter.shared.release() } }

    do {
      let request = try await commonClient.makeVideoRequest(path)
      let asset = AVURLAsset(
        url: request.url,
        options: ["AVURLAssetHTTPHeaderFieldsKey": request.headers]
      )
      let generator = AVAssetImageGenerator(asset: asset)
      generator.appliesPreferredTrackTransform = true
      generator.maximumSize = CGSize(width: 800, height: 800)

      let (cgImage, _) = try await generator.image(at: .zero)
      try Task.checkCancellation()
      let decoded = UIImage(cgImage: cgImage)
      await ChatImageDecodedCache.shared.set(decoded, for: cacheKey)
      image = decoded
    } catch is CancellationError {
      // ignore
    } catch {
      Logger.videoPlayer.notice(
        "thumbnail load failed: \(error.localizedDescription, privacy: .private)"
      )
      hasFailed = true
    }

    isLoading = false
  }
}
