//
//  Data+ImageDownscale.swift
//  ToneAtelier
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

extension Data {
  enum UploadPreparation: Equatable, Sendable {
    case usable(Data, transformed: Bool)
    case wrongFormat
    case tooSmall(min: Int)
    case notReducible
  }

  /// 업로드 직전 단계의 통합 처리. 형식 거부 → 단변 검증 → 5MB 이하 리사이즈.
  /// minShortSide nil 이면 단변 검증 skip (Chat 등).
  func preparedForUpload(maxBytes: Int, minShortSide: Int? = nil) -> UploadPreparation {
    guard isAcceptedImageFormat else { return .wrongFormat }
    if let minShortSide,
       let dim = imagePixelSize,
       Int(Swift.min(dim.width, dim.height)) < minShortSide {
      return .tooSmall(min: minShortSide)
    }
    if count <= maxBytes { return .usable(self, transformed: false) }
    guard let downscaled = imageDownscaled(under: maxBytes) else { return .notReducible }
    return .usable(downscaled, transformed: true)
  }

  var imagePixelSize: CGSize? {
    guard
      let source = CGImageSourceCreateWithData(self as CFData, nil),
      let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    else { return nil }
    let width = (props[kCGImagePropertyPixelWidth] as? CGFloat) ?? 0
    let height = (props[kCGImagePropertyPixelHeight] as? CGFloat) ?? 0
    guard width > 0, height > 0 else { return nil }
    return CGSize(width: width, height: height)
  }

  /// JPEG 으로 재인코딩해서 maxBytes 이하로 축소. 이미 미만이면 self 그대로.
  /// max dimension / 압축률을 단계적으로 낮춰 수렴 시도.
  func imageDownscaled(under maxBytes: Int) -> Data? {
    guard count > maxBytes else { return self }
    guard let source = CGImageSourceCreateWithData(self as CFData, nil) else { return nil }

    let dimensions: [CGFloat] = [3840, 2560, 1920, 1280, 960, 640]
    let qualities: [CGFloat] = [0.8, 0.6, 0.4]

    for maxDim in dimensions {
      let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: maxDim
      ]
      guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
        continue
      }
      for quality in qualities {
        guard let encoded = Self.encodeJPEG(cgImage, quality: quality) else { continue }
        if encoded.count <= maxBytes { return encoded }
      }
    }
    return nil
  }

  private static func encodeJPEG(_ image: CGImage, quality: CGFloat) -> Data? {
    let buffer = NSMutableData()
    guard let dest = CGImageDestinationCreateWithData(
      buffer as CFMutableData,
      UTType.jpeg.identifier as CFString,
      1,
      nil
    ) else { return nil }
    let props: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
    CGImageDestinationAddImage(dest, image, props as CFDictionary)
    guard CGImageDestinationFinalize(dest) else { return nil }
    return buffer as Data
  }
}
