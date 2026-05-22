//
//  Data+ImageFormat.swift
//  ToneAtelier
//

import Foundation

extension Data {
  enum ImageFormat: Equatable, Sendable {
    case jpeg
    case png
    case heic
    case unknown
  }

  var detectedImageFormat: ImageFormat {
    guard count >= 12 else { return .unknown }
    let bytes = [UInt8](prefix(12))

    if bytes[0] == 0xFF, bytes[1] == 0xD8, bytes[2] == 0xFF {
      return .jpeg
    }

    if bytes[0] == 0x89, bytes[1] == 0x50, bytes[2] == 0x4E, bytes[3] == 0x47,
       bytes[4] == 0x0D, bytes[5] == 0x0A, bytes[6] == 0x1A, bytes[7] == 0x0A {
      return .png
    }

    if bytes[4] == 0x66, bytes[5] == 0x74, bytes[6] == 0x79, bytes[7] == 0x70 {
      let brand = String(decoding: bytes[8..<12], as: UTF8.self)
      let heicBrands: Set<String> = ["heic", "heix", "mif1", "msf1", "hevc", "hevx"]
      if heicBrands.contains(brand) {
        return .heic
      }
    }

    return .unknown
  }

  var isAcceptedImageFormat: Bool {
    switch detectedImageFormat {
    case .jpeg, .png, .heic: return true
    case .unknown: return false
    }
  }
}
