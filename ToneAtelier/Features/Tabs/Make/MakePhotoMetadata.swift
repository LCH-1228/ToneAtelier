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

  var jsonValue: JSONValue {
    var object: [String: JSONValue] = [
      "file_size": .number(Double(fileSize))
    ]

    object.setString(camera, forKey: "camera")
    object.setString(lensInfo, forKey: "lens_info")
    object.setNumber(focalLength, forKey: "focal_length")
    object.setNumber(aperture, forKey: "aperture")
    object.setNumber(iso.map(Double.init), forKey: "iso")
    object.setString(shutterSpeed, forKey: "shutter_speed")
    object.setNumber(pixelWidth.map(Double.init), forKey: "pixel_width")
    object.setNumber(pixelHeight.map(Double.init), forKey: "pixel_height")
    object.setString(format, forKey: "format")
    object.setString(dateTimeOriginal, forKey: "date_time_original")
    object.setNumber(latitude, forKey: "latitude")
    object.setNumber(longitude, forKey: "longitude")

    return .object(object)
  }
}

private extension Dictionary where Key == String, Value == JSONValue {
  mutating func setString(_ value: String?, forKey key: String) {
    guard let value, !value.isEmpty else { return }
    self[key] = .string(value)
  }

  mutating func setNumber(_ value: Double?, forKey key: String) {
    guard let value else { return }
    self[key] = .number(value)
  }
}
