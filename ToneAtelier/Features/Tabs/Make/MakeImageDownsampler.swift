//
//  MakeImageDownsampler.swift
//  ToneAtelier
//
//  Created by Codex on 4/28/26.
//

import Foundation
import ImageIO
import UniformTypeIdentifiers

enum MakeImageDownsampler {
  nonisolated static func cgImage(
    from imageFileURL: URL,
    maxPixelLength: CGFloat
  ) throws -> CGImage {
    let sourceOptions = [
      kCGImageSourceShouldCache: false
    ] as CFDictionary

    guard let source = CGImageSourceCreateWithURL(imageFileURL as CFURL, sourceOptions) else {
      throw MakeImageDownsamplerError.invalidImage
    }

    return try cgImage(from: source, maxPixelLength: maxPixelLength)
  }

  nonisolated static func jpegData(
    from imageFileURL: URL,
    maxPixelLength: CGFloat,
    compressionQuality: CGFloat
  ) throws -> Data {
    let image = try cgImage(from: imageFileURL, maxPixelLength: maxPixelLength)
    return try jpegData(from: image, compressionQuality: compressionQuality)
  }

  nonisolated static func jpegData(
    from image: CGImage,
    compressionQuality: CGFloat
  ) throws -> Data {
    let data = NSMutableData()

    guard let destination = CGImageDestinationCreateWithData(
      data,
      UTType.jpeg.identifier as CFString,
      1,
      nil
    ) else {
      throw MakeImageDownsamplerError.encodingFailed
    }

    let options = [
      kCGImageDestinationLossyCompressionQuality: compressionQuality
    ] as CFDictionary
    CGImageDestinationAddImage(destination, image, options)

    guard CGImageDestinationFinalize(destination) else {
      throw MakeImageDownsamplerError.encodingFailed
    }

    return data as Data
  }

  private nonisolated static func cgImage(
    from source: CGImageSource,
    maxPixelLength: CGFloat
  ) throws -> CGImage {
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

    return cgImage
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
