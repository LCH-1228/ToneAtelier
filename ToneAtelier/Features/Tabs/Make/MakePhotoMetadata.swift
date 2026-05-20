//
//  MakePhotoMetadata.swift
//  ToneAtelier
//
//  Created by Codex on 4/28/26.
//

import Foundation

struct MakePhotoMetadata: Equatable, Sendable {
  var camera: String?
  var lensInfo: String?
  var focalLength: Double?
  var aperture: Double?
  var iso: Int?
  var shutterSpeed: String?
  var pixelWidth: Int?
  var pixelHeight: Int?
  var fileSize: Int
  var format: String?
  var dateTimeOriginal: String?
  var latitude: Double?
  var longitude: Double?

  /// 빈 문자열은 nil 처리해 spec PhotoMetadataDTO 형식으로 매핑한다.
  var dto: PhotoMetadataDTO {
    PhotoMetadataDTO(
      camera: camera?.nilIfEmpty,
      lensInfo: lensInfo?.nilIfEmpty,
      focalLength: focalLength,
      aperture: aperture,
      iso: iso,
      shutterSpeed: shutterSpeed?.nilIfEmpty,
      pixelWidth: pixelWidth,
      pixelHeight: pixelHeight,
      fileSize: Double(fileSize),
      format: format?.nilIfEmpty,
      dateTimeOriginal: dateTimeOriginal?.nilIfEmpty,
      latitude: latitude,
      longitude: longitude
    )
  }
}

private extension String {
  var nilIfEmpty: String? { isEmpty ? nil : self }
}
