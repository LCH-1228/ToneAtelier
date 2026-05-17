//
//  LocalVideoThumbnailView.swift
//  ToneAtelier
//
//  Created by LCH on 5/18/26.
//

import AVFoundation
import OSLog
import SwiftUI
import UIKit

/// 로컬 비디오 `Data` 의 첫 프레임을 추출해 표시한다.
/// 서버 path 기반인 `VideoThumbnailView` 와 달리 첨부 후 업로드 전 단계의 미리보기 전용.
struct LocalVideoThumbnailView: View {
  let id: UUID
  let data: Data
  let mimeType: String

  @State private var thumbnail: UIImage?
  @State private var hasFailed = false

  var body: some View {
    Group {
      if let thumbnail {
        Image(uiImage: thumbnail)
          .resizable()
          .scaledToFill()
      } else if hasFailed {
        placeholder(systemImage: "video.slash")
      } else {
        placeholder(systemImage: "video")
      }
    }
    .task(id: id) { await extract() }
  }

  private func placeholder(systemImage: String) -> some View {
    ZStack {
      AppTheme.blackTurquoise
      Image(systemName: systemImage)
        .foregroundStyle(AppTheme.gray60)
    }
  }

  private var cacheKey: String { "local-video-thumb:\(id.uuidString)" }

  private func extract() async {
    if let cached = await ChatImageDecodedCache.shared.image(for: cacheKey) {
      thumbnail = cached
      return
    }

    let temporaryURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("LocalVideoThumb-\(id.uuidString).\(fileExtension)")

    do {
      try data.write(to: temporaryURL)
      defer { try? FileManager.default.removeItem(at: temporaryURL) }

      let asset = AVURLAsset(url: temporaryURL)
      let generator = AVAssetImageGenerator(asset: asset)
      generator.appliesPreferredTrackTransform = true
      generator.maximumSize = CGSize(width: 800, height: 800)

      let (cgImage, _) = try await generator.image(at: .zero)
      try Task.checkCancellation()
      let image = UIImage(cgImage: cgImage)
      await ChatImageDecodedCache.shared.set(image, for: cacheKey)
      thumbnail = image
    } catch is CancellationError {
      return
    } catch {
      Logger.videoPlayer.notice(
        "local thumbnail extract failed: \(error.localizedDescription, privacy: .private)"
      )
      hasFailed = true
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
