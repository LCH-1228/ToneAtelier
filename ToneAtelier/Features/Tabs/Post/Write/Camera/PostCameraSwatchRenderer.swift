//
//  PostCameraSwatchRenderer.swift
//  ToneAtelier
//
//  필터 시트의 4×N 그리드 cell 에 라이브 카메라 프레임 + 각 필터의 MakeFilterValues 를 적용한
//  thumbnail 을 비동기 렌더 + 캐시한다. baseImage 가 없을 땐 procedural 그라디언트 폴백.
//

import CoreImage
import OSLog
import SwiftUI
import UIKit

final class PostCameraSwatchRenderer: @unchecked Sendable {
  /// 시트 cell 들이 공유하는 단일 인스턴스 — 캐시 hit 률을 위해 카메라 진입 동안 살아있어야.
  nonisolated static let shared = PostCameraSwatchRenderer()

  private let context = CIContext()
  private let cacheLock = NSLock()
  nonisolated(unsafe) private var cache: [String: UIImage] = [:]

  deinit {
    Logger.postCamera.debug("Deinit: \(String(describing: Self.self), privacy: .public)")
  }

  /// baseImage 가 있으면 라이브 카메라 프레임 + 필터값 적용, 없으면 procedural 그라디언트 폴백.
  /// baseImage 가 있을 때는 캐시하지 않는다(프레임이 바뀌면 결과가 달라야 하므로).
  /// pixelSize 는 cell 의 실제 표시 사이즈 × displayScale — 호출측이 명시적으로 전달.
  nonisolated func render(
    filter: PostCameraFilter,
    baseImage: CIImage? = nil,
    pixelSize: CGFloat
  ) async -> UIImage? {
    if baseImage == nil, let cached = cachedImage(forID: filter.id) {
      return cached
    }
    return await Task.detached(priority: .userInitiated) { [self] in
      let baseCI: CIImage
      if let baseImage {
        baseCI = squareCrop(baseImage)
      } else if let procedural = makeBaseSample(size: pixelSize) {
        baseCI = procedural
      } else {
        return nil
      }
      let filtered = PostCameraFrameFilter.apply(baseCI, values: filter.filterValues)
      guard let cgImage = context.createCGImage(filtered, from: filtered.extent) else { return nil }
      let image = UIImage(cgImage: cgImage)
      if baseImage == nil {
        storeCache(image, forID: filter.id)
      }
      return image
    }.value
  }

  nonisolated private func cachedImage(forID id: String) -> UIImage? {
    cacheLock.lock()
    defer { cacheLock.unlock() }
    return cache[id]
  }

  nonisolated private func storeCache(_ image: UIImage, forID id: String) {
    cacheLock.lock()
    cache[id] = image
    cacheLock.unlock()
  }

  /// 카메라 프레임은 portrait 비율 → cell square 표시에 맞춰 중앙 정사각형 crop.
  nonisolated private func squareCrop(_ image: CIImage) -> CIImage {
    let extent = image.extent
    let edge = min(extent.width, extent.height)
    let originX = extent.origin.x + (extent.width - edge) / 2
    let originY = extent.origin.y + (extent.height - edge) / 2
    return image.cropped(to: CGRect(x: originX, y: originY, width: edge, height: edge))
  }

  /// 사진처럼 보이는 고정된 다색 그라디언트 (sky-cloud-skin-earth).
  nonisolated private func makeBaseSample(size: CGFloat) -> CIImage? {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
    let baseImage = renderer.image { ctx in
      let cgContext = ctx.cgContext
      let colorSpace = CGColorSpaceCreateDeviceRGB()
      let stops: [(UIColor, CGFloat)] = [
        (UIColor(red: 0.45, green: 0.62, blue: 0.85, alpha: 1), 0.00),
        (UIColor(red: 0.78, green: 0.82, blue: 0.88, alpha: 1), 0.30),
        (UIColor(red: 0.93, green: 0.78, blue: 0.62, alpha: 1), 0.55),
        (UIColor(red: 0.62, green: 0.45, blue: 0.32, alpha: 1), 0.80),
        (UIColor(red: 0.22, green: 0.18, blue: 0.16, alpha: 1), 1.00)
      ]
      let colors = stops.map(\.0.cgColor) as CFArray
      let locations = stops.map(\.1)
      guard let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: colors,
        locations: locations
      ) else { return }
      cgContext.drawLinearGradient(
        gradient,
        start: .zero,
        end: CGPoint(x: 0, y: size),
        options: []
      )
    }
    guard let cgImage = baseImage.cgImage else { return nil }
    return CIImage(cgImage: cgImage)
  }
}
