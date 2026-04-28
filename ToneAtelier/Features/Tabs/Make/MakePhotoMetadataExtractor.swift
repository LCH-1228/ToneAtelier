//
//  MakePhotoMetadataExtractor.swift
//  ToneAtelier
//
//  Created by Codex on 4/27/26.
//

import Foundation
import ImageIO

enum MakePhotoMetadataExtractor {
  nonisolated static func makeRegisteredPhoto(from fileURL: URL) throws -> MakeFeature.RegisteredPhoto {
    let previewMaxPixelLength: CGFloat = 1_600
    let thumbnailMaxPixelLength: CGFloat = 240
    let properties = imageProperties(from: fileURL)
    let exif = dictionary(from: properties, key: kCGImagePropertyExifDictionary)
    let tiff = dictionary(from: properties, key: kCGImagePropertyTIFFDictionary)
    let gps = dictionary(from: properties, key: kCGImagePropertyGPSDictionary)
    let previewImageData = try MakeImageDownsampler.jpegData(
      from: fileURL,
      maxPixelLength: previewMaxPixelLength,
      compressionQuality: 0.86
    )
    let thumbnailImageData = try MakeImageDownsampler.jpegData(
      from: fileURL,
      maxPixelLength: thumbnailMaxPixelLength,
      compressionQuality: 0.82
    )
    let byteCount = fileSize(from: fileURL)

    return MakeFeature.RegisteredPhoto(
      imageFileURL: fileURL,
      previewImageData: previewImageData,
      thumbnailImageData: thumbnailImageData,
      exif: MakeFeature.ExifInfo(
        deviceLine: deviceLine(from: tiff),
        cameraLine: cameraLine(from: exif, tiff: tiff),
        fileLine: fileLine(from: properties, byteCount: byteCount),
        locationLine: locationLine(from: gps)
      ),
      metadata: MakePhotoMetadata(
        camera: rawDeviceLine(from: tiff),
        lensInfo: lensInfo(from: exif, tiff: tiff),
        focalLength: numericValue(from: exif[kCGImagePropertyExifFocalLenIn35mmFilm])
          ?? numericValue(from: exif[kCGImagePropertyExifFocalLength]),
        aperture: numericValue(from: exif[kCGImagePropertyExifFNumber]),
        iso: isoValue(from: exif[kCGImagePropertyExifISOSpeedRatings]),
        shutterSpeed: shutterSpeed(from: exif[kCGImagePropertyExifExposureTime]),
        pixelWidth: intValue(from: properties[kCGImagePropertyPixelWidth]),
        pixelHeight: intValue(from: properties[kCGImagePropertyPixelHeight]),
        fileSize: byteCount,
        format: imageFormat(from: fileURL),
        dateTimeOriginal: isoDateTime(from: exif[kCGImagePropertyExifDateTimeOriginal]),
        latitude: signedCoordinate(
          value: gps[kCGImagePropertyGPSLatitude],
          ref: trimmedString(from: gps[kCGImagePropertyGPSLatitudeRef])
        ),
        longitude: signedCoordinate(
          value: gps[kCGImagePropertyGPSLongitude],
          ref: trimmedString(from: gps[kCGImagePropertyGPSLongitudeRef])
        )
      )
    )
  }

  private nonisolated static func imageProperties(from fileURL: URL) -> [CFString: Any] {
    guard
      let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    else {
      return [:]
    }

    return properties
  }

  private nonisolated static func fileSize(from fileURL: URL) -> Int {
    let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey])
    return values?.fileSize ?? 0
  }

  private nonisolated static func dictionary(from properties: [CFString: Any], key: CFString) -> [CFString: Any] {
    properties[key] as? [CFString: Any] ?? [:]
  }

  private nonisolated static func deviceLine(from tiff: [CFString: Any]) -> String {
    rawDeviceLine(from: tiff) ?? "Apple iPhone 16 Pro"
  }

  private nonisolated static func rawDeviceLine(from tiff: [CFString: Any]) -> String? {
    let make = trimmedString(from: tiff[kCGImagePropertyTIFFMake])
    let model = trimmedString(from: tiff[kCGImagePropertyTIFFModel])
    let line = [make, model].compactMap { $0 }.joined(separator: " ")
    return line.isEmpty ? nil : line
  }

  private nonisolated static func cameraLine(from exif: [CFString: Any], tiff: [CFString: Any]) -> String {
    let lensModel = lensInfo(from: exif, tiff: tiff)
    let focalLength = formattedNumber(from: exif[kCGImagePropertyExifFocalLenIn35mmFilm])
      ?? formattedNumber(from: exif[kCGImagePropertyExifFocalLength])
    let aperture = formattedDecimal(from: exif[kCGImagePropertyExifFNumber], prefix: "ƒ ")
    let iso = formattedISO(from: exif[kCGImagePropertyExifISOSpeedRatings])

    let parts = [
      lensModel ?? "와이드 카메라",
      focalLength.map { "\($0) mm" },
      aperture,
      iso
    ].compactMap { $0 }

    return parts.joined(separator: " - ")
  }

  private nonisolated static func lensInfo(from exif: [CFString: Any], tiff: [CFString: Any]) -> String? {
    trimmedString(from: exif[kCGImagePropertyExifLensModel])
      ?? trimmedString(from: tiff[kCGImagePropertyTIFFModel])
  }

  private nonisolated static func fileLine(from properties: [CFString: Any], byteCount: Int) -> String {
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

  private nonisolated static func locationLine(from gps: [CFString: Any]) -> String? {
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
      return nil
    }

    return String(format: "GPS %.4f, %.4f", latitude, longitude)
  }

  private nonisolated static func signedCoordinate(value: Any?, ref: String?) -> Double? {
    guard let number = numericValue(from: value) else { return nil }
    return ["S", "W"].contains(ref?.uppercased() ?? "") ? -number : number
  }

  private nonisolated static func formattedISO(from value: Any?) -> String? {
    isoValue(from: value).map { "ISO \($0)" }
  }

  private nonisolated static func isoValue(from value: Any?) -> Int? {
    if let values = value as? [NSNumber], let first = values.first {
      return first.intValue
    }

    if let number = numericValue(from: value) {
      return Int(number)
    }

    return nil
  }

  private nonisolated static func formattedNumber(from value: Any?) -> String? {
    guard let number = numericValue(from: value) else { return nil }
    return number == floor(number) ? String(Int(number)) : String(format: "%.1f", number)
  }

  private nonisolated static func formattedDecimal(from value: Any?, prefix: String) -> String? {
    guard let number = numericValue(from: value) else { return nil }
    return prefix + String(format: "%.1f", number)
  }

  private nonisolated static func numericValue(from value: Any?) -> Double? {
    if let number = value as? NSNumber {
      return number.doubleValue
    }

    if let string = value as? String {
      return Double(string)
    }

    return nil
  }

  private nonisolated static func intValue(from value: Any?) -> Int? {
    if let number = value as? NSNumber {
      return number.intValue
    }

    if let int = value as? Int {
      return int
    }

    if let string = value as? String {
      return Int(string)
    }

    return nil
  }

  private nonisolated static func shutterSpeed(from value: Any?) -> String? {
    guard let exposureTime = numericValue(from: value), exposureTime > 0 else {
      return nil
    }

    if exposureTime < 1 {
      return "1/\(Int((1 / exposureTime).rounded())) sec"
    }

    return String(format: "%.2f sec", exposureTime)
  }

  private nonisolated static func isoDateTime(from value: Any?) -> String? {
    guard let rawValue = trimmedString(from: value) else { return nil }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"

    guard let date = formatter.date(from: rawValue) else {
      return rawValue
    }

    let isoFormatter = ISO8601DateFormatter()
    isoFormatter.timeZone = TimeZone(secondsFromGMT: 0)
    isoFormatter.formatOptions = [.withInternetDateTime]
    return isoFormatter.string(from: date)
  }

  private nonisolated static func imageFormat(from fileURL: URL) -> String? {
    guard
      let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
      let type = CGImageSourceGetType(source) as String?
    else {
      return nil
    }

    if type.contains("jpeg") {
      return "JPEG"
    }

    if type.contains("png") {
      return "PNG"
    }

    return type.components(separatedBy: ".").last?.uppercased()
  }

  private nonisolated static func trimmedString(from value: Any?) -> String? {
    guard let string = value as? String else { return nil }
    let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
