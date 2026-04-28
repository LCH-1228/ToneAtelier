//
//  MakeImageDownsampler.swift
//  ToneAtelier
//
//  Created by Codex on 4/28/26.
//

import Foundation
import ImageIO
import UIKit

enum MakeImageDownsampler {
  static func image(
    from imageData: Data,
    maxPixelLength: CGFloat
  ) throws -> UIImage {
    let sourceOptions = [
      kCGImageSourceShouldCache: false
    ] as CFDictionary

    guard let source = CGImageSourceCreateWithData(imageData as CFData, sourceOptions) else {
      throw MakeImageDownsamplerError.invalidImage
    }

    return try image(from: source, maxPixelLength: maxPixelLength)
  }

  static func jpegData(
    from imageData: Data,
    maxPixelLength: CGFloat,
    compressionQuality: CGFloat
  ) throws -> Data {
    let image = try image(from: imageData, maxPixelLength: maxPixelLength)

    guard let data = image.jpegData(compressionQuality: compressionQuality) else {
      throw MakeImageDownsamplerError.encodingFailed
    }

    return data
  }

  private static func image(
    from source: CGImageSource,
    maxPixelLength: CGFloat
  ) throws -> UIImage {
    let pixelLength = max(1, Int(maxPixelLength.rounded(.up)))
    let thumbnailOptions = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceShouldCacheImmediately: true,
      kCGImageSourceThumbnailMaxPixelSize: pixelLength
    ] as CFDictionary

    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
      throw MakeImageDownsamplerError.invalidImage
    }

    return UIImage(cgImage: cgImage)
  }
}

enum MakeImageDownsamplerError: LocalizedError {
  case invalidImage
  case encodingFailed

  var errorDescription: String? {
    switch self {
    case .invalidImage:
      return "불러올 수 있는 이미지 파일이 아니에요."
    case .encodingFailed:
      return "이미지 미리보기를 만들 수 없어요."
    }
  }
}
