//
//  PostCameraSession.swift
//  ToneAtelier
//

@preconcurrency import AVFoundation
import CoreImage
import OSLog
import UIKit

protocol PostCameraSessionFrameDelegate: AnyObject, Sendable {
  /// 매 프레임마다 호출. main actor 가 아닌 capture queue 에서 호출되므로 UI 갱신 시 큐 전환 필요.
  nonisolated func session(_ session: PostCameraSession, didOutput image: CIImage)
}

protocol PostCameraSessionPhotoDelegate: AnyObject, Sendable {
  nonisolated func session(_ session: PostCameraSession, didCaptureRawImage image: CIImage)
  nonisolated func session(_ session: PostCameraSession, didFailCaptureWith error: Error)
}

/// AVCaptureSession + AVCaptureVideoDataOutput + AVCapturePhotoOutput 를 묶어 관리.
/// 라이브 프리뷰용 비디오 프레임은 frameDelegate 로, 셔터 결과는 photoDelegate 로 흘려준다.
nonisolated final class PostCameraSession:
  NSObject,
  AVCaptureVideoDataOutputSampleBufferDelegate,
  AVCapturePhotoCaptureDelegate,
  @unchecked Sendable {
  weak var frameDelegate: PostCameraSessionFrameDelegate?
  weak var photoDelegate: PostCameraSessionPhotoDelegate?

  /// 프레임 1차 콜백(MTKView)과 별개로 sheet preview 등 보조 구독자에게 frame 을 흘리는 broadcast.
  /// nonisolated(unsafe) 인 이유: capture queue 에서 호출되며 set 은 MainActor 가 함.
  nonisolated(unsafe) var onFrame: (@Sendable (CIImage) -> Void)?

  /// device 변경(초기 설정/flip) 직후 사용 가능한 lens preset 과 default 선택을 broadcast.
  /// session queue 에서 호출되므로 view 는 MainActor 로 hop 후 store 에 보내야 한다.
  nonisolated(unsafe) var onZoomPresetsChanged: (@Sendable ([PostCameraZoomPreset], PostCameraZoomPreset) -> Void)?

  private let session = AVCaptureSession()
  private let videoOutput = AVCaptureVideoDataOutput()
  private let photoOutput = AVCapturePhotoOutput()
  private let sessionQueue = DispatchQueue(label: "PostCameraSession.session")
  private let videoQueue = DispatchQueue(label: "PostCameraSession.video")

  private var currentInput: AVCaptureDeviceInput?
  private var currentPosition: AVCaptureDevice.Position = .back
  private var currentFlashMode: AVCaptureDevice.FlashMode = .off

  private let frameLock = NSLock()
  nonisolated(unsafe) private var lastFrame: CIImage?

  /// 시트 cell 들이 라이브 카메라 프레임을 base 로 쓸 수 있도록 가장 최근 프레임을 노출.
  /// nil 이면 아직 첫 프레임이 도착하지 않은 상태.
  nonisolated func snapshotLatestFrame() -> CIImage? {
    frameLock.lock()
    defer { frameLock.unlock() }
    return lastFrame
  }

  override init() {
    super.init()
    configureSession()
  }

  deinit {
    Logger.postCamera.debug("Deinit: \(String(describing: Self.self), privacy: .public)")
    sessionQueue.async { [session] in
      if session.isRunning { session.stopRunning() }
    }
  }

  // MARK: - Lifecycle

  func start() {
    sessionQueue.async { [weak self] in
      guard let self else { return }
      if !session.isRunning {
        session.startRunning()
      }
    }
  }

  func stop() {
    sessionQueue.async { [weak self] in
      guard let self else { return }
      if session.isRunning {
        session.stopRunning()
      }
    }
  }

  // MARK: - Configuration

  func switchPosition(to position: AVCaptureDevice.Position) {
    sessionQueue.async { [weak self] in
      guard let self else { return }
      session.beginConfiguration()
      defer { session.commitConfiguration() }
      if let currentInput {
        session.removeInput(currentInput)
      }
      guard let device = bestDevice(for: position),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input) else {
        Logger.postCamera.error("switchPosition failed for \(position == .front ? "front" : "back", privacy: .public)")
        return
      }
      session.addInput(input)
      currentInput = input
      currentPosition = position
      configureVideoConnection()
      broadcastZoomPresets()
    }
  }

  func setFlashMode(_ mode: AVCaptureDevice.FlashMode) {
    currentFlashMode = mode
  }

  /// preview 의 normalized 좌표(0...1, 0...1) 를 device 좌표로 그대로 사용.
  /// AVFoundation 의 focusPointOfInterest 도 (0,0)=top-left, (1,1)=bottom-right 의 normalized 공간이라 추가 변환 불필요.
  nonisolated func setFocusAndExposure(point: CGPoint) {
    sessionQueue.async { [weak self] in
      guard let self, let device = currentInput?.device else { return }
      do {
        try device.lockForConfiguration()
        if device.isFocusPointOfInterestSupported {
          device.focusPointOfInterest = point
          if device.isFocusModeSupported(.autoFocus) {
            device.focusMode = .autoFocus
          }
        }
        if device.isExposurePointOfInterestSupported {
          device.exposurePointOfInterest = point
          if device.isExposureModeSupported(.autoExpose) {
            device.exposureMode = .autoExpose
          }
        }
        // 새 focus 시점에 EV bias 도 0 으로 reset.
        if device.isExposureModeSupported(.continuousAutoExposure) {
          device.setExposureTargetBias(0, completionHandler: nil)
        }
        device.unlockForConfiguration()
      } catch {
        Logger.postCamera.error("setFocusAndExposure failed: \(error.localizedDescription, privacy: .public)")
      }
    }
  }

  /// EV bias. 일반적으로 -2 ... +2 범위. device 의 min/max 로 clamp.
  nonisolated func setExposureBias(_ bias: Float) {
    sessionQueue.async { [weak self] in
      guard let self, let device = currentInput?.device else { return }
      let clamped = max(device.minExposureTargetBias, min(device.maxExposureTargetBias, bias))
      do {
        try device.lockForConfiguration()
        device.setExposureTargetBias(clamped, completionHandler: nil)
        device.unlockForConfiguration()
      } catch {
        Logger.postCamera.error("setExposureBias failed: \(error.localizedDescription, privacy: .public)")
      }
    }
  }

  /// 현재 device 의 가상 카메라 switch-over 정보로 노출 가능한 lens preset 산출.
  /// session queue 에서 직렬화하여 currentInput 동시 변경과 race 방지.
  nonisolated func availableZoomPresets() -> [PostCameraZoomPreset] {
    sessionQueue.sync {
      guard let device = currentInput?.device else { return [.wide] }
      let switchCount = device.virtualDeviceSwitchOverVideoZoomFactors.count
      switch switchCount {
      case 0:
        return [.wide]
      case 1:
        if device.deviceType == .builtInDualCamera {
          return [.wide, .telephoto]
        }
        return [.ultraWide, .wide]
      default:
        return [.ultraWide, .wide, .telephoto]
      }
    }
  }

  /// preset 에 해당하는 videoZoomFactor 를 device 에 적용. 잘못된 범위는 clamp.
  nonisolated func setZoom(preset: PostCameraZoomPreset) {
    sessionQueue.async { [weak self] in
      guard let self, let device = currentInput?.device else { return }
      let switchOver = device.virtualDeviceSwitchOverVideoZoomFactors.map { CGFloat(truncating: $0) }
      let target: CGFloat
      switch preset {
      case .ultraWide:
        target = 1.0
      case .wide:
        if device.deviceType == .builtInTripleCamera || device.deviceType == .builtInDualWideCamera {
          target = switchOver.first ?? 2.0
        } else {
          target = 1.0
        }
      case .telephoto:
        if device.deviceType == .builtInTripleCamera {
          target = switchOver.last ?? 6.0
        } else if device.deviceType == .builtInDualCamera {
          target = switchOver.first ?? 2.0
        } else {
          target = 3.0
        }
      }
      let clamped = max(
        device.minAvailableVideoZoomFactor,
        min(device.maxAvailableVideoZoomFactor, target)
      )
      do {
        try device.lockForConfiguration()
        device.videoZoomFactor = clamped
        device.unlockForConfiguration()
      } catch {
        Logger.postCamera.error(
          "setZoom \(preset.displayLabel, privacy: .public) failed: \(error.localizedDescription, privacy: .public)"
        )
      }
    }
  }

  private func broadcastZoomPresets() {
    let presets: [PostCameraZoomPreset]
    if let device = currentInput?.device {
      let switchCount = device.virtualDeviceSwitchOverVideoZoomFactors.count
      switch switchCount {
      case 0:
        presets = [.wide]
      case 1:
        presets = device.deviceType == .builtInDualCamera
          ? [.wide, .telephoto]
          : [.ultraWide, .wide]
      default:
        presets = [.ultraWide, .wide, .telephoto]
      }
    } else {
      presets = [.wide]
    }
    onZoomPresetsChanged?(presets, .wide)
  }

  func capturePhoto() {
    sessionQueue.async { [weak self] in
      guard let self else { return }
      guard session.isRunning else { return }
      let settings = AVCapturePhotoSettings()
      if photoOutput.supportedFlashModes.contains(currentFlashMode) {
        settings.flashMode = currentFlashMode
      }
      photoOutput.capturePhoto(with: settings, delegate: self)
    }
  }

  // MARK: - Private

  private func configureSession() {
    sessionQueue.async { [weak self] in
      guard let self else { return }
      session.beginConfiguration()
      defer { session.commitConfiguration() }
      session.sessionPreset = .photo

      if let device = bestDevice(for: .back),
         let input = try? AVCaptureDeviceInput(device: device),
         session.canAddInput(input) {
        session.addInput(input)
        currentInput = input
        currentPosition = .back
      }

      videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
      videoOutput.alwaysDiscardsLateVideoFrames = true
      videoOutput.videoSettings = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
      ]
      if session.canAddOutput(videoOutput) {
        session.addOutput(videoOutput)
      }

      if session.canAddOutput(photoOutput) {
        session.addOutput(photoOutput)
      }

      configureVideoConnection()
      broadcastZoomPresets()
    }
  }

  private func bestDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
    if let triple = AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: position) {
      return triple
    }
    if let dual = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: position) {
      return dual
    }
    if let wide = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) {
      return wide
    }
    return AVCaptureDevice.default(for: .video)
  }

  private func configureVideoConnection() {
    guard let connection = videoOutput.connection(with: .video) else { return }
    let portraitAngle: CGFloat = 90
    if connection.isVideoRotationAngleSupported(portraitAngle) {
      connection.videoRotationAngle = portraitAngle
    }
    if currentPosition == .front, connection.isVideoMirroringSupported {
      connection.automaticallyAdjustsVideoMirroring = false
      connection.isVideoMirrored = true
    } else if connection.isVideoMirroringSupported {
      connection.automaticallyAdjustsVideoMirroring = true
    }
  }
}

// MARK: - Sample buffer

extension PostCameraSession {
  nonisolated func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    let image = CIImage(cvPixelBuffer: pixelBuffer)
    frameLock.lock()
    lastFrame = image
    frameLock.unlock()
    frameDelegate?.session(self, didOutput: image)
    onFrame?(image)
  }
}

// MARK: - Photo output

extension PostCameraSession {
  nonisolated func photoOutput(
    _ output: AVCapturePhotoOutput,
    didFinishProcessingPhoto photo: AVCapturePhoto,
    error: Error?
  ) {
    if let error {
      photoDelegate?.session(self, didFailCaptureWith: error)
      return
    }
    guard
      let data = photo.fileDataRepresentation(),
      let uiImage = UIImage(data: data),
      let cgImage = uiImage.cgImage
    else {
      photoDelegate?.session(
        self,
        didFailCaptureWith: PostCameraSessionError.captureUnavailable
      )
      return
    }
    var ciImage = CIImage(cgImage: cgImage)
    let orientation = uiImage.imageOrientation.cgImagePropertyOrientation
    ciImage = ciImage.oriented(orientation)
    photoDelegate?.session(self, didCaptureRawImage: ciImage)
  }
}

enum PostCameraSessionError: Error {
  case captureUnavailable
}

private extension UIImage.Orientation {
  /// CIImage.oriented(_:) 에 그대로 넣을 수 있는 CGImagePropertyOrientation 매핑.
  nonisolated var cgImagePropertyOrientation: CGImagePropertyOrientation {
    switch self {
    case .up: return .up
    case .upMirrored: return .upMirrored
    case .down: return .down
    case .downMirrored: return .downMirrored
    case .leftMirrored: return .leftMirrored
    case .right: return .right
    case .rightMirrored: return .rightMirrored
    case .left: return .left
    @unknown default: return .up
    }
  }
}
