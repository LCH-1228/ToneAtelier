//
//  MakeFilterUploadFileFactory.swift
//  ToneAtelier
//
//  Created by Codex on 4/28/26.
//

import Foundation
import CoreGraphics

enum MakeFilterUploadFileFactory {
  nonisolated static func makeUploadFiles(from imageFileURL: URL) throws -> [UploadFile] {
    let previewData = try jpegPreviewDataFittingLimit(from: imageFileURL)

    // MARK: - LUT Preview Rendering
    // TODO: 필터 렌더링이 연결되면 previews_filtered에는 보정된 이미지 데이터를 전달한다.
    return [
      UploadFile(
        fieldName: "files",
        fileName: "previews_original.jpg",
        mimeType: "image/jpeg",
        data: previewData
      ),
      UploadFile(
        fieldName: "files",
        fileName: "previews_filtered.jpg",
        mimeType: "image/jpeg",
        data: previewData
      )
    ]
  }

  private nonisolated static func jpegPreviewDataFittingLimit(from imageFileURL: URL) throws -> Data {
    let maximumFileByteCount = 2 * 1024 * 1024
    let previewPixelLengths: [CGFloat] = [2048, 1600, 1280, 1024, 768]
    let jpegQualities: [CGFloat] = [0.92, 0.82, 0.72, 0.62, 0.52, 0.42]

    for pixelLength in previewPixelLengths {
      let previewImage = try MakeImageDownsampler.cgImage(
        from: imageFileURL,
        maxPixelLength: pixelLength
      )

      for quality in jpegQualities {
        let data = try MakeImageDownsampler.jpegData(
          from: previewImage,
          compressionQuality: quality
        )

        if data.count <= maximumFileByteCount {
          return data
        }
      }
    }

    throw MakeFilterUploadFileFactoryError.fileTooLarge
  }
}

private enum MakeFilterUploadFileFactoryError: LocalizedError {
  case fileTooLarge

  var errorDescription: String? {
    switch self {
    case .fileTooLarge:
      return "미리보기 이미지를 2MB 이하로 만들 수 없어요."
    }
  }
}
