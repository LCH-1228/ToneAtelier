//
//  PostCameraPermissions.swift
//  ToneAtelier
//

import AVFoundation
import Photos

enum PostCameraPermissions {
  /// VIDEO/SLO-MO 모드 첫 진입 시 호출. 이미 허용된 상태면 즉시 true.
  nonisolated static func ensureMicrophone() async -> Bool {
    switch AVCaptureDevice.authorizationStatus(for: .audio) {
    case .authorized:
      return true
    case .notDetermined:
      return await AVCaptureDevice.requestAccess(for: .audio)
    case .denied, .restricted:
      return false
    @unknown default:
      return false
    }
  }

  /// 첫 라이브러리 저장 직전 호출.
  nonisolated static func ensurePhotoLibraryAdd() async -> Bool {
    switch PHPhotoLibrary.authorizationStatus(for: .addOnly) {
    case .authorized, .limited:
      return true
    case .notDetermined:
      let result = await withCheckedContinuation { continuation in
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
          continuation.resume(returning: status)
        }
      }
      return result == .authorized || result == .limited
    case .denied, .restricted:
      return false
    @unknown default:
      return false
    }
  }
}
