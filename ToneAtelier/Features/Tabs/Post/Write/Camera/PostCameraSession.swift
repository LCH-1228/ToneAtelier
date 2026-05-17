//
//  PostCameraSession.swift
//  ToneAtelier
//

@preconcurrency import AVFoundation
import CoreImage
import OSLog

protocol PostCameraSessionFrameDelegate: AnyObject, Sendable {
  /// 매 프레임마다 호출. main actor 가 아닌 capture queue 에서 호출되므로 UI 갱신 시 큐 전환 필요.
  nonisolated func session(_ session: PostCameraSession, didOutput image: CIImage)
}

protocol PostCameraSessionPhotoDelegate: AnyObject, Sendable {
  nonisolated func session(_ session: PostCameraSession, didCaptureRawImage image: CIImage, photo: AVCapturePhoto)
  nonisolated func session(_ session: PostCameraSession, didFailCaptureWith error: Error)
}

/// AVCaptureSession + AVCaptureVideoDataOutput + AVCapturePhotoOutput + AVCaptureMovieFileOutput 묶음.
/// 라이브 프리뷰용 비디오 프레임은 frameDelegate 로, 셔터 결과는 photoDelegate 로,
/// 녹화 결과는 startRecording/stopRecording 의 onFinish 콜백으로 흘려준다.
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
  private let movieOutput = AVCaptureMovieFileOutput()
  private let sessionQueue = DispatchQueue(label: "PostCameraSession.session")
  private let videoQueue = DispatchQueue(label: "PostCameraSession.video")

  private var currentInput: AVCaptureDeviceInput?
  private var audioInput: AVCaptureDeviceInput?
  private var currentPosition: AVCaptureDevice.Position = .back
  private var currentFlashMode: AVCaptureDevice.FlashMode = .off
  private var movieOutputAdded = false
  private var photoOutputAdded = false

  private let recordingLock = NSLock()
  nonisolated(unsafe) private var filteredEncoder: PostCameraFilteredVideoEncoder?
  nonisolated(unsafe) private var recordingBridge: PostCameraRecordingBridge?
  nonisolated(unsafe) private var recordingFilteredCallback: (@Sendable (Result<URL, Error>) -> Void)?

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
}

extension PostCameraSession {
  // MARK: - Mode-specific configuration

  func configureForMode(_ mode: PostCameraMode) {
    sessionQueue.async { [weak self] in
      guard let self else { return }
      session.beginConfiguration()
      defer { session.commitConfiguration() }

      switch mode {
      case .photo:
        applyPhotoPreset()
        ensurePhotoOutputAdded()
        removeAudioInputIfNeeded()
        removeMovieOutputIfNeeded()
      case .video:
        applyVideoPreset()
        ensureMovieOutputAdded()
        ensureAudioInputAdded()
      }
    }
  }

  private func applyPhotoPreset() {
    if session.canSetSessionPreset(.photo) {
      session.sessionPreset = .photo
    }
  }

  private func applyVideoPreset() {
    if session.canSetSessionPreset(.high) {
      session.sessionPreset = .high
    }
  }

  private func ensurePhotoOutputAdded() {
    if !photoOutputAdded, session.canAddOutput(photoOutput) {
      session.addOutput(photoOutput)
      photoOutputAdded = true
    }
  }

  private func ensureMovieOutputAdded() {
    if !movieOutputAdded, session.canAddOutput(movieOutput) {
      session.addOutput(movieOutput)
      movieOutputAdded = true
    }
    if let connection = movieOutput.connection(with: .video) {
      let portraitAngle: CGFloat = 90
      if connection.isVideoRotationAngleSupported(portraitAngle) {
        connection.videoRotationAngle = portraitAngle
      }
    }
  }

  private func removeMovieOutputIfNeeded() {
    if movieOutputAdded {
      session.removeOutput(movieOutput)
      movieOutputAdded = false
    }
  }

  private func ensureAudioInputAdded() {
    guard audioInput == nil,
          let device = AVCaptureDevice.default(for: .audio),
          let input = try? AVCaptureDeviceInput(device: device),
          session.canAddInput(input) else { return }
    session.addInput(input)
    audioInput = input
  }

  private func removeAudioInputIfNeeded() {
    if let audioInput {
      session.removeInput(audioInput)
      self.audioInput = nil
    }
  }

  // MARK: - Capture (photo)

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

  // MARK: - Recording (video)

  func startRecording(
    filterValues: MakeFilterValues,
    saveFiltered: Bool,
    drawableSize: CGSize,
    onFinishOriginal: @escaping @Sendable (Result<URL, Error>) -> Void,
    onFinishFiltered: @escaping @Sendable (Result<URL, Error>) -> Void
  ) {
    sessionQueue.async { [weak self] in
      guard let self else { return }
      guard !movieOutput.isRecording else { return }

      recordingLock.lock()
      recordingFilteredCallback = saveFiltered ? onFinishFiltered : nil
      if saveFiltered {
        let url = Self.makeTemporaryURL(suffix: "filtered.mov")
        do {
          let encoder = try PostCameraFilteredVideoEncoder(
            outputURL: url,
            size: drawableSize,
            filterValues: filterValues
          )
          encoder.start()
          filteredEncoder = encoder
        } catch {
          Logger.postCamera.error("filtered encoder init failed: \(error.localizedDescription, privacy: .public)")
          onFinishFiltered(.failure(error))
        }
      }
      recordingLock.unlock()

      let originalURL = Self.makeTemporaryURL(suffix: "original.mov")
      let bridge = PostCameraRecordingBridge(onFinish: onFinishOriginal)
      recordingBridge = bridge
      movieOutput.startRecording(to: originalURL, recordingDelegate: bridge)
    }
  }

  func stopRecording() {
    sessionQueue.async { [weak self] in
      guard let self else { return }
      if movieOutput.isRecording {
        movieOutput.stopRecording()
      }
      let encoder = filteredEncoder
      let callback = recordingFilteredCallback
      filteredEncoder = nil
      recordingFilteredCallback = nil
      Task { [encoder, callback] in
        guard let encoder else { return }
        await encoder.finish()
        callback?(.success(encoder.url))
      }
    }
  }

  private static func makeTemporaryURL(suffix: String) -> URL {
    let stamp = Int(Date().timeIntervalSince1970 * 1000)
    return FileManager.default.temporaryDirectory
      .appendingPathComponent("post_camera_\(stamp)_\(suffix)")
  }

  // MARK: - Private setup

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

      ensurePhotoOutputAdded()

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
    frameDelegate?.session(self, didOutput: image)
    onFrame?(image)

    if let filteredEncoder, movieOutput.isRecording {
      let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
      filteredEncoder.append(image: image, presentationTime: pts)
    }
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
    guard let cgImage = photo.cgImageRepresentation() else {
      photoDelegate?.session(
        self,
        didFailCaptureWith: PostCameraSessionError.captureUnavailable
      )
      return
    }
    var ciImage = CIImage(cgImage: cgImage)
    let orientationRaw = photo.metadata[kCGImagePropertyOrientation as String] as? UInt32
    if let orientationRaw, let orientation = CGImagePropertyOrientation(rawValue: orientationRaw) {
      ciImage = ciImage.oriented(orientation)
    }
    photoDelegate?.session(self, didCaptureRawImage: ciImage, photo: photo)
  }
}

enum PostCameraSessionError: Error {
  case captureUnavailable
}
