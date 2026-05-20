//
//  PostCameraFilteredVideoEncoder.swift
//  ToneAtelier
//

@preconcurrency import AVFoundation
import CoreImage
import OSLog

/// 라이브 비디오 프레임에 PostCameraFrameFilter 를 적용해 .mov 로 인코딩하는 일회용 writer.
/// session 의 onFrame 가로채기로 매 프레임 append 호출.
final class PostCameraFilteredVideoEncoder: @unchecked Sendable {
  enum EncoderError: Error {
    case writerSetupFailed
    case appendFailed
  }

  private let writer: AVAssetWriter
  private let writerInput: AVAssetWriterInput
  private let pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor
  private let context: CIContext
  private let filterValues: MakeFilterValues
  private let outputURL: URL
  private let stateLock = NSLock()
  nonisolated(unsafe) private var sessionStartedAt: CMTime?
  nonisolated(unsafe) private var isFinishedFlag = false

  var url: URL { outputURL }

  init(outputURL: URL, size: CGSize, filterValues: MakeFilterValues) throws {
    self.outputURL = outputURL
    self.filterValues = filterValues
    self.context = CIContext()

    do {
      writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
    } catch {
      Logger.postCamera.error("encoder writer init failed: \(error.localizedDescription, privacy: .public)")
      throw EncoderError.writerSetupFailed
    }

    let outputSettings: [String: Any] = [
      AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: Int(size.width),
      AVVideoHeightKey: Int(size.height)
    ]
    writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
    writerInput.expectsMediaDataInRealTime = true

    let attrs: [String: Any] = [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
      kCVPixelBufferWidthKey as String: Int(size.width),
      kCVPixelBufferHeightKey as String: Int(size.height)
    ]
    pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: writerInput,
      sourcePixelBufferAttributes: attrs
    )

    guard writer.canAdd(writerInput) else {
      throw EncoderError.writerSetupFailed
    }
    writer.add(writerInput)
  }

  func start() {
    guard writer.startWriting() else {
      Logger.postCamera.error("encoder startWriting failed: \(self.writer.error?.localizedDescription ?? "?", privacy: .public)")
      return
    }
  }

  func append(image: CIImage, presentationTime: CMTime) {
    guard writerInput.isReadyForMoreMediaData else { return }
    stateLock.lock()
    if sessionStartedAt == nil {
      sessionStartedAt = presentationTime
      writer.startSession(atSourceTime: presentationTime)
    }
    stateLock.unlock()

    let filtered = PostCameraFrameFilter.apply(image, values: filterValues)
    var pixelBuffer: CVPixelBuffer?
    guard let pool = pixelBufferAdaptor.pixelBufferPool else { return }
    let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
    guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return }
    context.render(filtered, to: buffer)
    pixelBufferAdaptor.append(buffer, withPresentationTime: presentationTime)
  }

  func finish() async {
    if isFinishedFlag { return }
    isFinishedFlag = true
    writerInput.markAsFinished()
    await writer.finishWriting()
  }
}
