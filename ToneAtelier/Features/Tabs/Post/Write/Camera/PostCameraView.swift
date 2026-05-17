//
//  PostCameraView.swift
//  ToneAtelier
//
//  Pencil node: z8RX6L (Post Custom Camera View)
//

import AVFoundation
import Combine
import ComposableArchitecture
import CoreImage
import OSLog
import SwiftUI
import UIKit

struct PostCameraView: View {
  @Bindable var store: StoreOf<PostCameraFeature>

  @StateObject private var sessionHolder = PostCameraSessionHolder()
  @StateObject private var frameRelay = PostCameraFrameRelay()
  @State private var permissionState: PermissionState = .pending
  @State private var permissionAlertPresented = false
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    rootContent
      .preferredColorScheme(.dark)
      .task { await preparePermissionAndStart() }
      .onAppear { wireSessionCallbacks() }
      .onDisappear { teardownSessionCallbacks() }
      .modifier(SessionStateChangeModifier(store: store, sessionHolder: sessionHolder, scenePhase: scenePhase))
      .onChange(of: store.isCapturing) { oldValue, newValue in
        if !oldValue, newValue { triggerCapture() }
      }
      .onChange(of: store.isRecording) { oldValue, newValue in
        if !oldValue, newValue {
          startRecordingFlow()
        } else if oldValue, !newValue {
          sessionHolder.session.stopRecording()
        }
      }
      .alert("카메라 권한이 꺼져 있어요", isPresented: $permissionAlertPresented) {
        Button("설정 열기") { openAppSettings() }
        Button("취소", role: .cancel) { store.send(.closeTapped) }
      } message: {
        Text("필터 카메라를 쓰려면 설정 > 개인 정보 보호 > 카메라에서 ToneAtelier 를 허용해 주세요.")
      }
      .sheet(isPresented: $store.isSheetPresented) {
        PostCameraFilterSheet(store: store, frameRelay: frameRelay)
          .presentationDetents([.fraction(0.55)])
          .presentationDragIndicator(.visible)
          .presentationCornerRadius(24)
          .presentationBackground(AppTheme.blackTurquoise)
      }
      .sheet(isPresented: $store.isPresentingSettingsSheet) {
        PostCameraSettingsSheet(store: store)
      }
  }

  @ViewBuilder
  private var rootContent: some View {
    ZStack {
      AppTheme.background.ignoresSafeArea()
      switch permissionState {
      case .pending:
        ProgressView().tint(AppTheme.gray30)
      case .denied:
        deniedPlaceholder
      case .granted:
        cameraStack
      }
      if store.isRecording {
        PostCameraRecordingOverlay(
          duration: store.recordingDuration,
          onShutterTap: { store.send(.shutterTapped) }
        )
      }
    }
  }

  private func wireSessionCallbacks() {
    let relay = frameRelay
    sessionHolder.session.onFrame = { frame in relay.ingest(frame) }
    sessionHolder.session.onZoomPresetsChanged = { presets, _ in
      Task { @MainActor in store.send(.zoomPresetsReported(presets)) }
    }
  }

  private func teardownSessionCallbacks() {
    sessionHolder.session.onFrame = nil
    sessionHolder.session.onZoomPresetsChanged = nil
    sessionHolder.session.stop()
  }

  private func triggerCapture() {
    sessionHolder.bindPhotoDelegate(
      saveTarget: store.settings.saveTarget,
      values: PostCameraFeature.resolvedFilterValues(state: store.state)
    ) { result in
      Task { @MainActor in store.send(.captureResponse(result)) }
    }
    sessionHolder.session.capturePhoto()
  }

  // MARK: - Layout

  @ViewBuilder
  private var cameraStack: some View {
    let resolvedValues = PostCameraFeature.resolvedFilterValues(state: store.state)
    let isRecording = store.isRecording

    ZStack {
      VStack(spacing: 0) {
        topSection
          .frame(height: 162)
          .opacity(isRecording ? 0 : 1)
          .allowsHitTesting(!isRecording)

        PostCameraPreviewSection(
          session: sessionHolder.session,
          filterValues: resolvedValues,
          splitFraction: store.splitFraction,
          isFilterActive: store.selectedFilter != nil,
          onSplitFractionChange: { store.send(.splitFractionChanged($0)) },
          onPreviewTap: { store.send(.previewTapped(at: $0)) }
        )
        .frame(maxWidth: .infinity)
        .layoutPriority(1)
        .overlay { focusIndicatorOverlay }
        .overlay(alignment: .bottom) {
          previewBottomOverlays
            .opacity(isRecording ? 0 : 1)
            .allowsHitTesting(!isRecording)
        }

        PostCameraBottomBar(
          cameraMode: store.cameraMode,
          isCapturing: store.isCapturing,
          isFilterActive: store.selectedFilter != nil,
          onModeTap: { store.send(.modeTapped($0)) },
          onGalleryTap: { store.send(.galleryTapped) },
          onShutterTap: { store.send(.shutterTapped) },
          onFilterTap: { store.send(.sheetOpenTapped) }
        )
        .frame(height: 162)
        .opacity(isRecording ? 0 : 1)
        .allowsHitTesting(!isRecording)
      }

      if let message = store.captureError ?? store.recordingError {
        Text(message)
          .pretendard(.caption1)
          .foregroundStyle(AppTheme.gray60)
          .padding(.horizontal, 20)
          .frame(maxHeight: .infinity, alignment: .top)
          .padding(.top, 8)
      }
    }
  }

  @ViewBuilder
  private var focusIndicatorOverlay: some View {
    if let focus = store.focusIndicator {
      GeometryReader { proxy in
        let size = proxy.size
        PostCameraFocusIndicator(
          exposureBias: store.exposureBias,
          onExposureBiasChange: { store.send(.exposureBiasChanged($0)) }
        )
        .position(
          x: max(0, min(size.width, size.width * focus.normalizedPoint.x)),
          y: max(0, min(size.height, size.height * focus.normalizedPoint.y))
        )
      }
      .id(focus.id)
      .transition(.opacity)
      .animation(.easeInOut(duration: 0.18), value: focus.id)
      .allowsHitTesting(true)
    }
  }

  @ViewBuilder
  private var previewBottomOverlays: some View {
    VStack(spacing: 8) {
      if let selected = store.selectedFilter {
        PostCameraIntensitySliderOverlay(
          filterTitle: selected.title,
          intensity: store.filterIntensity,
          onChange: { store.send(.intensityChanged($0)) }
        )
      }
      if !store.availableZoomPresets.isEmpty {
        PostCameraLensSwitcher(
          presets: store.availableZoomPresets,
          selected: store.selectedZoomPreset,
          onTap: { store.send(.zoomPresetTapped($0)) }
        )
      }
    }
    .padding(.bottom, 24)
  }

  private var topSection: some View {
    ZStack(alignment: .top) {
      VStack(spacing: 0) {
        Spacer().frame(height: 37)
        PostCameraTopBar(
          flashMode: store.flashMode,
          onClose: { store.send(.closeTapped) },
          onFlashTap: { store.send(.flashTapped) },
          onFlipTap: { store.send(.flipTapped) },
          onSettingsTap: { store.send(.settingsTapped) }
        )
        Spacer()
      }

      if let selected = store.selectedFilter, !store.isSheetPresented {
        VStack(spacing: 0) {
          Spacer().frame(height: 41)
          PostCameraActiveChip(
            title: selected.title,
            intensityPercent: Int((store.filterIntensity * 100).rounded()),
            swatchColor: selected.swatchColor
          )
          Spacer()
        }
      }
    }
  }

  private var deniedPlaceholder: some View {
    VStack(spacing: 12) {
      Image(systemName: "camera.slash")
        .font(AppTheme.symbol(size: 36, weight: .regular))
        .foregroundStyle(AppTheme.gray60)
      Text("카메라 권한이 필요해요")
        .pretendard(.body3Bold)
        .foregroundStyle(AppTheme.gray30)
      Text("설정에서 ToneAtelier 의 카메라 사용을 허용해야 촬영할 수 있어요.")
        .pretendard(.caption1)
        .multilineTextAlignment(.center)
        .foregroundStyle(AppTheme.gray60)
        .padding(.horizontal, 32)
      Button("설정 열기") { openAppSettings() }
        .pretendard(.captionBold)
        .foregroundStyle(AppTheme.gray30)
        .padding(.horizontal, 18)
        .frame(height: 36)
        .background(AppTheme.blackTurquoise)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(AppTheme.brightTurquoise, lineWidth: 1))
    }
  }

  // MARK: - Permission / lifecycle

  @MainActor
  private func preparePermissionAndStart() async {
    let granted = await sessionHolder.ensureCameraAuthorized()
    if granted {
      permissionState = .granted
      sessionHolder.session.switchPosition(to: store.cameraPosition.avPosition)
      sessionHolder.session.setFlashMode(store.flashMode.avFlashMode)
      sessionHolder.session.configureForMode(store.cameraMode)
      sessionHolder.session.start()
      store.send(.task)
    } else {
      permissionState = .denied
      permissionAlertPresented = true
    }
  }

  private func openAppSettings() {
    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
    UIApplication.shared.open(url)
  }

  @MainActor
  private func startRecordingFlow() {
    let saveTarget = store.settings.saveTarget
    let filterValues = PostCameraFeature.resolvedFilterValues(state: store.state)
    Task { @MainActor in
      let micGranted = await PostCameraPermissions.ensureMicrophone()
      guard micGranted else {
        store.send(.recordingFinished(.failure(PostCameraSessionError.captureUnavailable)))
        return
      }
      let drawableSize = CGSize(width: 1080, height: 1920)
      sessionHolder.startRecording(
        saveTarget: saveTarget,
        filterValues: filterValues,
        drawableSize: drawableSize
      ) { result in
        Task { @MainActor in
          store.send(.recordingFinished(result))
        }
      }
    }
  }

  private enum PermissionState {
    case pending
    case granted
    case denied
  }
}

/// SwiftUI 의 lifecycle 안에서 PostCameraSession 의 단일 인스턴스를 보존하기 위한 보관함.
/// View 가 다시 렌더되더라도 동일 session 인스턴스가 유지된다.
@MainActor
final class PostCameraSessionHolder: ObservableObject {
  let session = PostCameraSession()
  private var photoBridge: PhotoCaptureBridge?
  private var recordingCollector: PostCameraRecordingCollector?

  deinit {
    Logger.postCamera.debug("Deinit: \(String(describing: Self.self), privacy: .public)")
  }

  func ensureCameraAuthorized() async -> Bool {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      return true
    case .notDetermined:
      return await AVCaptureDevice.requestAccess(for: .video)
    case .denied, .restricted:
      return false
    @unknown default:
      return false
    }
  }

  func bindPhotoDelegate(
    saveTarget: PostCameraSaveTarget,
    values: MakeFilterValues,
    onResult: @escaping @Sendable (Result<PostCameraCaptureOutput, Error>) -> Void
  ) {
    let bridge = PhotoCaptureBridge(
      saveTarget: saveTarget,
      filterValues: values,
      onResult: onResult
    )
    session.photoDelegate = bridge
    photoBridge = bridge
  }

  func startRecording(
    saveTarget: PostCameraSaveTarget,
    filterValues: MakeFilterValues,
    drawableSize: CGSize,
    onFinish: @escaping @Sendable (Result<PostCameraRecordedClip, Error>) -> Void
  ) {
    // 필터 미선택(.default) 이면 원본/필터본이 동일하므로 인코더 우회 — 라이브러리 중복 저장 회피.
    let saveFiltered = saveTarget != .originalOnly && filterValues != .default
    let collector = PostCameraRecordingCollector(
      saveFiltered: saveFiltered,
      onFinish: onFinish
    )
    recordingCollector = collector
    session.startRecording(
      filterValues: filterValues,
      saveFiltered: saveFiltered,
      drawableSize: drawableSize,
      onFinishOriginal: { result in collector.handleOriginal(result) },
      onFinishFiltered: { result in collector.handleFiltered(result) }
    )
  }
}

/// AVCapturePhotoCaptureDelegate 결과를 한 번만 받아 store 에 다시 던지는 일회용 bridge.
/// saveTarget 따라 원본/필터 두 데이터 묶음(PostCameraCaptureOutput) 으로 반환.
final class PhotoCaptureBridge: NSObject, PostCameraSessionPhotoDelegate, @unchecked Sendable {
  private let saveTarget: PostCameraSaveTarget
  private let filterValues: MakeFilterValues
  private let onResult: @Sendable (Result<PostCameraCaptureOutput, Error>) -> Void
  private let firedLock = NSLock()
  nonisolated(unsafe) private var hasFired = false
  private let context = CIContext()

  init(
    saveTarget: PostCameraSaveTarget,
    filterValues: MakeFilterValues,
    onResult: @escaping @Sendable (Result<PostCameraCaptureOutput, Error>) -> Void
  ) {
    self.saveTarget = saveTarget
    self.filterValues = filterValues
    self.onResult = onResult
  }

  deinit {
    Logger.postCamera.debug("Deinit: \(String(describing: Self.self), privacy: .public)")
  }

  nonisolated func session(_ session: PostCameraSession, didCaptureRawImage image: CIImage, photo: AVCapturePhoto) {
    guard claimFiring() else { return }
    Task.detached { [self] in
      do {
        let output = try processPhoto(image: image)
        onResult(.success(output))
      } catch {
        onResult(.failure(error))
      }
    }
  }

  nonisolated func session(_ session: PostCameraSession, didFailCaptureWith error: Error) {
    guard claimFiring() else { return }
    onResult(.failure(error))
  }

  nonisolated private func claimFiring() -> Bool {
    firedLock.lock()
    defer { firedLock.unlock() }
    guard !hasFired else { return false }
    hasFired = true
    return true
  }

  nonisolated private func processPhoto(image: CIImage) throws -> PostCameraCaptureOutput {
    let needsOriginal = saveTarget != .filteredOnly
    let needsFiltered = filterValues != .default
    var original: Data?
    var filtered: Data?
    if needsOriginal {
      original = try jpegData(image: image)
    }
    if needsFiltered {
      let filteredImage = PostCameraFrameFilter.apply(image, values: filterValues)
      filtered = try jpegData(image: filteredImage)
    } else if !needsOriginal {
      // saveTarget=.filteredOnly 인데 필터가 .default 인 edge case → 원본을 만들어 attachment 보장
      original = try jpegData(image: image)
    }
    return PostCameraCaptureOutput(originalData: original, filteredData: filtered)
  }

  nonisolated private func jpegData(image: CIImage) throws -> Data {
    let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
    let options: [CIImageRepresentationOption: Any] = [
      CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): 0.92
    ]
    guard let data = context.jpegRepresentation(of: image, colorSpace: colorSpace, options: options) else {
      throw PostCameraSessionError.captureUnavailable
    }
    return data
  }
}

/// onChange chain 을 modifier 로 묶어 PostCameraView.body 의 type-check 부담을 분산.
private struct SessionStateChangeModifier: ViewModifier {
  let store: StoreOf<PostCameraFeature>
  let sessionHolder: PostCameraSessionHolder
  let scenePhase: ScenePhase

  func body(content: Content) -> some View {
    content
      .onChange(of: store.cameraPosition) { _, newValue in
        sessionHolder.session.switchPosition(to: newValue.avPosition)
      }
      .onChange(of: store.flashMode) { _, newValue in
        sessionHolder.session.setFlashMode(newValue.avFlashMode)
      }
      .onChange(of: store.selectedZoomPreset) { _, newValue in
        sessionHolder.session.setZoom(preset: newValue)
      }
      .onChange(of: store.focusIndicator?.id) { _, _ in
        if let point = store.focusIndicator?.normalizedPoint {
          sessionHolder.session.setFocusAndExposure(point: point)
        }
      }
      .onChange(of: store.exposureBias) { _, newValue in
        sessionHolder.session.setExposureBias(newValue)
      }
      .onChange(of: store.cameraMode) { _, newValue in
        sessionHolder.session.configureForMode(newValue)
      }
      .onChange(of: scenePhase) { _, newValue in
        if newValue != .active, store.isRecording {
          store.send(.recordingStopRequested)
        }
      }
  }
}

private extension PostCameraPosition {
  var avPosition: AVCaptureDevice.Position {
    switch self {
    case .back: return .back
    case .front: return .front
    }
  }
}

private extension PostCameraFlashMode {
  var avFlashMode: AVCaptureDevice.FlashMode {
    switch self {
    case .off: return .off
    case .on: return .on
    case .auto: return .auto
    }
  }
}
