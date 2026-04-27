//
//  MakePhotoMetadataExtractor.swift
//  ToneAtelier
//
//  Created by Codex on 4/27/26.
//

import Foundation
import ImageIO

enum MakePhotoMetadataExtractor {
  static func makeRegisteredPhoto(from data: Data) -> MakeFeature.RegisteredPhoto {
    let properties = imageProperties(from: data)
    let exif = dictionary(from: properties, key: kCGImagePropertyExifDictionary)
    let tiff = dictionary(from: properties, key: kCGImagePropertyTIFFDictionary)
    let gps = dictionary(from: properties, key: kCGImagePropertyGPSDictionary)

    return MakeFeature.RegisteredPhoto(
      imageData: data,
      exif: MakeFeature.ExifInfo(
        deviceLine: deviceLine(from: tiff),
        cameraLine: cameraLine(from: exif, tiff: tiff),
        fileLine: fileLine(from: properties, byteCount: data.count),
        locationLine: locationLine(from: gps)
      )
    )
  }

  private static func imageProperties(from data: Data) -> [CFString: Any] {
    guard
      let source = CGImageSourceCreateWithData(data as CFData, nil),
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    else {
      return [:]
    }

    return properties
  }

  private static func dictionary(from properties: [CFString: Any], key: CFString) -> [CFString: Any] {
    properties[key] as? [CFString: Any] ?? [:]
  }

  private static func deviceLine(from tiff: [CFString: Any]) -> String {
    let make = trimmedString(from: tiff[kCGImagePropertyTIFFMake])
    let model = trimmedString(from: tiff[kCGImagePropertyTIFFModel])
    let line = [make, model].compactMap { $0 }.joined(separator: " ")
    return line.isEmpty ? "Apple iPhone 16 Pro" : line
  }

  private static func cameraLine(from exif: [CFString: Any], tiff: [CFString: Any]) -> String {
    let lensModel = trimmedString(from: exif[kCGImagePropertyExifLensModel])
    let fallbackModel = trimmedString(from: tiff[kCGImagePropertyTIFFModel])
    let focalLength = formattedNumber(from: exif[kCGImagePropertyExifFocalLenIn35mmFilm])
      ?? formattedNumber(from: exif[kCGImagePropertyExifFocalLength])
    let aperture = formattedDecimal(from: exif[kCGImagePropertyExifFNumber], prefix: "ƒ ")
    let iso = formattedISO(from: exif[kCGImagePropertyExifISOSpeedRatings])

    let parts = [
      lensModel ?? fallbackModel ?? "와이드 카메라",
      focalLength.map { "\($0) mm" },
      aperture,
      iso
    ].compactMap { $0 }

    return parts.joined(separator: " - ")
  }

  private static func fileLine(from properties: [CFString: Any], byteCount: Int) -> String {
    let pixelWidth = properties[kCGImagePropertyPixelWidth] as? Int
    let pixelHeight = properties[kCGImagePropertyPixelHeight] as? Int
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file

    guard let pixelWidth, let pixelHeight else {
      return formatter.string(fromByteCount: Int64(byteCount))
    }

    let megaPixels = Double(pixelWidth * pixelHeight) / 1_000_000
    return String(
      format: "%.0fMP • %d × %d • %@",
      megaPixels.rounded(),
      pixelWidth,
      pixelHeight,
      formatter.string(fromByteCount: Int64(byteCount))
    )
  }

  private static func locationLine(from gps: [CFString: Any]) -> String? {
    guard
      let latitude = signedCoordinate(
        value: gps[kCGImagePropertyGPSLatitude],
        ref: trimmedString(from: gps[kCGImagePropertyGPSLatitudeRef])
      ),
      let longitude = signedCoordinate(
        value: gps[kCGImagePropertyGPSLongitude],
        ref: trimmedString(from: gps[kCGImagePropertyGPSLongitudeRef])
      )
    else {
      return "서울 영등포구 선유로 9길 30"
    }

    return String(format: "GPS %.4f, %.4f", latitude, longitude)
  }

  private static func signedCoordinate(value: Any?, ref: String?) -> Double? {
    guard let number = numericValue(from: value) else { return nil }
    return ["S", "W"].contains(ref?.uppercased() ?? "") ? -number : number
  }

  private static func formattedISO(from value: Any?) -> String? {
    if let values = value as? [NSNumber], let first = values.first {
      return "ISO \(first.intValue)"
    }

    if let number = numericValue(from: value) {
      return "ISO \(Int(number))"
    }

    return nil
  }

  private static func formattedNumber(from value: Any?) -> String? {
    guard let number = numericValue(from: value) else { return nil }
    return number == floor(number) ? String(Int(number)) : String(format: "%.1f", number)
  }

  private static func formattedDecimal(from value: Any?, prefix: String) -> String? {
    guard let number = numericValue(from: value) else { return nil }
    return prefix + String(format: "%.1f", number)
  }

  private static func numericValue(from value: Any?) -> Double? {
    if let number = value as? NSNumber {
      return number.doubleValue
    }

    if let string = value as? String {
      return Double(string)
    }

    return nil
  }

  private static func trimmedString(from value: Any?) -> String? {
    guard let string = value as? String else { return nil }
    let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
