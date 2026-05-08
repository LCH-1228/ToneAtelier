//
//  PostCameraPreviewView.swift
//  ToneAtelier
//

import CoreImage
import MetalKit
import OSLog
import SwiftUI
import UIKit

/// SwiftUI 에서 라이브 카메라 프리뷰를 띄우는 representable.
/// MTKView + CIContext 로 매 프레임을 (좌측 원본 / 우측 필터 적용) 합성해 그린다.
struct PostCameraPreviewView: UIViewRepresentable {
  let session: PostCameraSession
  let filterValues: MakeFilterValues
  let splitFraction: Double

  func makeCoordinator() -> Coordinator { Coordinator() }

  func makeUIView(context: Context) -> MetalCIPreview {
    let view = MetalCIPreview()
    view.coordinator = context.coordinator
    context.coordinator.attach(to: view, session: session)
    context.coordinator.update(filterValues: filterValues, splitFraction: splitFraction)
    return view
  }

  func updateUIView(_ uiView: MetalCIPreview, context: Context) {
    context.coordinator.update(filterValues: filterValues, splitFraction: splitFraction)
  }

  static func dismantleUIView(_ uiView: MetalCIPreview, coordinator: Coordinator) {
    coordinator.detach()
  }

  final class Coordinator: NSObject, PostCameraSessionFrameDelegate, @unchecked Sendable {
    fileprivate var preview: MetalCIPreview?
    private weak var session: PostCameraSession?
    nonisolated(unsafe) private var filterValues: MakeFilterValues = .default
    nonisolated(unsafe) private var splitFraction: Double = 0.5
    private let stateLock = NSLock()

    deinit {
      Logger.postCamera.debug("Deinit: \(String(describing: Self.self), privacy: .public)")
    }

    func attach(to view: MetalCIPreview, session: PostCameraSession) {
      self.preview = view
      self.session = session
      session.frameDelegate = self
    }

    func detach() {
      session?.frameDelegate = nil
      preview = nil
    }

    func update(filterValues: MakeFilterValues, splitFraction: Double) {
      stateLock.lock()
      self.filterValues = filterValues
      self.splitFraction = splitFraction
      stateLock.unlock()
    }

    // MARK: - PostCameraSessionFrameDelegate

    nonisolated func session(_ session: PostCameraSession, didOutput image: CIImage) {
      stateLock.lock()
      let values = filterValues
      let split = splitFraction
      stateLock.unlock()
      DispatchQueue.main.async { [weak self] in
        guard let self, let preview else { return }
        preview.lastFrame = image
        preview.lastFilterValues = values
        preview.lastSplitFraction = split
        preview.setNeedsDisplay(preview.bounds)
      }
    }
  }
}

/// MTKView + CIContext 로 라이브 합성 프리뷰를 그리는 UIView.
/// 매 프레임에 대해 좌측은 원본 CIImage, 우측은 필터 적용 CIImage 를 합성해 화면 비율에 맞춰 fit.
final class MetalCIPreview: MTKView {
  weak var coordinator: PostCameraPreviewView.Coordinator?
  fileprivate var lastFrame: CIImage?
  fileprivate var lastFilterValues: MakeFilterValues = .default
  fileprivate var lastSplitFraction: Double = 0.5

  private let ciContext: CIContext
  private let commandQueueRef: MTLCommandQueue?

  init() {
    let device = MTLCreateSystemDefaultDevice()
    let queue = device?.makeCommandQueue()
    self.commandQueueRef = queue
    if let device {
      self.ciContext = CIContext(mtlDevice: device)
    } else {
      self.ciContext = CIContext()
    }
    super.init(frame: .zero, device: device)
    framebufferOnly = false
    enableSetNeedsDisplay = true
    isPaused = true
    autoResizeDrawable = true
    backgroundColor = .black
    contentMode = .scaleAspectFill
    colorPixelFormat = .bgra8Unorm
    delegate = self
  }

  required init(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  deinit {
    Logger.postCamera.debug("Deinit: \(String(describing: Self.self), privacy: .public)")
  }
}

extension MetalCIPreview: MTKViewDelegate {
  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

  func draw(in view: MTKView) {
    guard
      let drawable = currentDrawable,
      let commandQueue = commandQueueRef,
      let commandBuffer = commandQueue.makeCommandBuffer(),
      let frame = lastFrame
    else { return }

    let drawableSize = view.drawableSize
    guard drawableSize.width > 0, drawableSize.height > 0 else { return }

    let composed = composedImage(
      original: frame,
      values: lastFilterValues,
      splitFraction: lastSplitFraction,
      drawableSize: drawableSize
    )

    ciContext.render(
      composed,
      to: drawable.texture,
      commandBuffer: commandBuffer,
      bounds: CGRect(origin: .zero, size: drawableSize),
      colorSpace: CGColorSpaceCreateDeviceRGB()
    )
    commandBuffer.present(drawable)
    commandBuffer.commit()
  }

  /// 입력 CIImage 를 drawableSize 에 aspectFill 로 맞춘 뒤,
  /// splitFraction 위치를 기준으로 좌 = 원본, 우 = 필터 적용 결과를 합성해 반환.
  private func composedImage(
    original: CIImage,
    values: MakeFilterValues,
    splitFraction: Double,
    drawableSize: CGSize
  ) -> CIImage {
    let extent = original.extent
    let scaleX = drawableSize.width / extent.width
    let scaleY = drawableSize.height / extent.height
    let scale = max(scaleX, scaleY)
    let scaled = original.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    let translatedX = (drawableSize.width - scaled.extent.width) / 2
    let translatedY = (drawableSize.height - scaled.extent.height) / 2
    let placedOriginal = scaled.transformed(
      by: CGAffineTransform(translationX: translatedX, y: translatedY)
    )
    let filtered = PostCameraFrameFilter.apply(placedOriginal, values: values)

    let splitX = drawableSize.width * CGFloat(max(0, min(1, splitFraction)))
    let leftRect = CGRect(x: 0, y: 0, width: splitX, height: drawableSize.height)
    let rightRect = CGRect(
      x: splitX,
      y: 0,
      width: drawableSize.width - splitX,
      height: drawableSize.height
    )

    let leftSlice = placedOriginal.cropped(to: leftRect)
    let rightSlice = filtered.cropped(to: rightRect)
    return rightSlice.composited(over: leftSlice)
      .cropped(to: CGRect(origin: .zero, size: drawableSize))
  }
}
