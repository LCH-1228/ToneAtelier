//
//  PostCameraLibrarySaver.swift
//  ToneAtelier
//

import Foundation
import OSLog
import Photos

enum PostCameraLibrarySaver {
  enum SaveError: Error {
    case unauthorized
    case underlying(Error)
  }

  nonisolated static func saveImage(data: Data) async throws {
    Logger.postCamera.debug("library saveImage enter bytes=\(data.count, privacy: .public)")
    guard await PostCameraPermissions.ensurePhotoLibraryAdd() else {
      throw SaveError.unauthorized
    }
    do {
      try await PHPhotoLibrary.shared().performChanges {
        let request = PHAssetCreationRequest.forAsset()
        request.addResource(with: .photo, data: data, options: nil)
      }
      Logger.postCamera.debug("library saveImage done")
    } catch {
      Logger.postCamera.error("library saveImage failed: \(error.localizedDescription, privacy: .public)")
      throw SaveError.underlying(error)
    }
  }

  nonisolated static func saveVideo(url: URL) async throws {
    guard await PostCameraPermissions.ensurePhotoLibraryAdd() else {
      throw SaveError.unauthorized
    }
    do {
      try await PHPhotoLibrary.shared().performChanges {
        PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: url)
      }
    } catch {
      Logger.postCamera.error("library saveVideo failed: \(error.localizedDescription, privacy: .public)")
      throw SaveError.underlying(error)
    }
  }
}
