//
//  MakeFilterUploadFileFactory.swift
//  ToneAtelier
//
//  Created by Codex on 4/28/26.
//

import Foundation
import UIKit

enum MakeFilterUploadFileFactory {
  private static let maximumFileByteCount = 2 * 1024 * 1024
  private static let previewPixelLengths: [CGFloat] = [2048, 1600, 1280, 1024, 768]
  private static let jpegQualities: [CGFloat] = [0.92, 0.82, 0.72, 0.62, 0.52, 0.42]

  static func makeUploadFiles(from imageData: Data) throws -> [UploadFile] {
    let previewData = try jpegPreviewDataFittingLimit(from: imageData)

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

  private static func jpegPreviewDataFittingLimit(from imageData: Data) throws -> Data {
    guard let image = UIImage(data: imageData), image.size.width > 0, image.size.height > 0 else {
      throw MakeFilterUploadFileFactoryError.invalidImage
    }

    for pixelLength in previewPixelLengths {
      let resizedImage = image.resizedForPreview(maxPixelLength: pixelLength)

      for quality in jpegQualities {
        guard let data = resizedImage.jpegData(compressionQuality: quality) else { continue }

        if data.count <= maximumFileByteCount {
          return data
        }
      }
    }

    throw MakeFilterUploadFileFactoryError.fileTooLarge
  }
}

private enum MakeFilterUploadFileFactoryError: LocalizedError {
  case invalidImage
  case fileTooLarge

  var errorDescription: String? {
    switch self {
    case .invalidImage:
      return "업로드할 수 있는 이미지 파일이 아니에요."
    case .fileTooLarge:
      return "미리보기 이미지를 2MB 이하로 만들 수 없어요."
    }
  }
}

private extension UIImage {
  func resizedForPreview(maxPixelLength: CGFloat) -> UIImage {
    let longestSide = max(size.width, size.height)
    guard longestSide > maxPixelLength else { return self }

    let scale = maxPixelLength / longestSide
    let targetSize = CGSize(
      width: size.width * scale,
      height: size.height * scale
    )

    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = false

    return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
      draw(in: CGRect(origin: .zero, size: targetSize))
    }
  }
}
