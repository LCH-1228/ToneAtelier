//
//  AVAsset+Transcode.swift
//  ToneAtelier
//

import AVFoundation
import Foundation

enum VideoTranscodeError: Error {
  case noSession
  case failed
}

extension AVURLAsset {
  /// `maxBytes` 이하의 mp4 파일을 만들어 반환. MediumQuality → LowQuality 단계.
  /// 임시 디렉터리에 결과 file 작성. caller 가 사용 후 cleanup 책임.
  nonisolated static func transcodeToMP4(inputURL: URL, maxBytes: Int64) async throws -> URL {
    let asset = AVURLAsset(url: inputURL)
    let presets = [
      AVAssetExportPresetMediumQuality,
      AVAssetExportPresetLowQuality
    ]
    for preset in presets {
      let outputURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(UUID().uuidString).mp4")
      guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
        continue
      }
      session.shouldOptimizeForNetworkUse = true
      do {
        try await session.export(to: outputURL, as: .mp4)
      } catch {
        try? FileManager.default.removeItem(at: outputURL)
        continue
      }
      let size = ((try? FileManager.default.attributesOfItem(atPath: outputURL.path))?[.size] as? Int64) ?? 0
      if size > 0, size <= maxBytes {
        return outputURL
      }
      try? FileManager.default.removeItem(at: outputURL)
    }
    throw VideoTranscodeError.failed
  }
}
