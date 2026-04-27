//
//  HomeDetailClient.swift
//  ToneAtelier
//
//  Created by Codex on 4/27/26.
//

import ComposableArchitecture
import Foundation

struct HomeDetailClient {
  var fetchDetail: @Sendable (_ filterID: String) async throws -> HomeDetailLoadedData
  var setLike: @Sendable (_ filterID: String, _ likeStatus: Bool) async throws -> Bool
}

extension HomeDetailClient: DependencyKey {
  static var liveValue: HomeDetailClient {
    @Dependency(\.filterClient) var filterClient

    return HomeDetailClient(
      fetchDetail: { filterID in
        let response = try await filterClient.detail(filterID)
        return HomeDetailResponseParser.loadedData(from: response)
      },
      setLike: { filterID, likeStatus in
        try await filterClient.setLike(filterID, likeStatus).like_status
      }
    )
  }

  static let testValue = HomeDetailClient(
    fetchDetail: { _ in throw APIError.transport("HomeDetailClient.fetchDetail testValue") },
    setLike: { _, _ in throw APIError.transport("HomeDetailClient.setLike testValue") }
  )
}

extension DependencyValues {
  var homeDetailClient: HomeDetailClient {
    get { self[HomeDetailClient.self] }
    set { self[HomeDetailClient.self] = newValue }
  }
}

private enum HomeDetailResponseParser {
  nonisolated static func loadedData(from value: JSONValue) -> HomeDetailLoadedData {
    let object = containerObject(from: value, preferredKeys: ["data", "filter", "item"])
    let creator = object["creator"]?.objectValue ?? object["user"]?.objectValue ?? object["author"]?.objectValue ?? [:]
    let files = imagePaths(from: object["files"])
    let metadata = object["photoMetadata"]?.objectValue ?? object["photo_metadata"]?.objectValue ?? [:]
    let filterValues = object["filterValues"]?.objectValue ?? object["filter_values"]?.objectValue ?? [:]

    let title = object.firstString(for: ["title", "name", "filter_name", "filterName"], default: "청록새록")
    let description = object.firstString(for: ["description", "summary", "content", "introduction"])
    let authorNick = creator.firstString(for: ["nick", "name", "displayName"], default: "윤새싹")
    let authorName = authorNick.uppercased()
    let authorSubtitle = creator.firstString(for: ["name", "introduction"], default: "SESAC YOON")
    let tags = creator.tags()

    return HomeDetailLoadedData(
      title: title,
      description: description,
      price: object.firstInt(for: ["price"], default: 2_000),
      buyerCount: object.firstInt(for: ["buyer_count", "buyerCount"], default: 2_400),
      likeCount: object.firstInt(for: ["like_count", "likeCount"], default: 800),
      isLiked: object.firstBool(for: ["is_liked", "isLiked", "like_status", "likeStatus"], default: false),
      isPurchased: object.firstBool(for: ["is_downloaded", "isDownloaded"], default: false),
      afterImageURL: files.first,
      beforeImageURL: files.dropFirst().first ?? files.first,
      authorName: authorName,
      authorSubtitle: authorSubtitle,
      authorProfileImageURL: creator.firstString(for: ["profileImage", "profile_image", "image", "image_url"]),
      authorTags: tags.isEmpty ? ["#섬세함", "#자연", "#미니멀"] : tags,
      exif: exifInfo(from: metadata, rootObject: object),
      presets: presets(from: filterValues)
    )
  }

  nonisolated private static func exifInfo(
    from object: [String: JSONValue],
    rootObject: [String: JSONValue]
  ) -> HomeDetailExifInfo {
    let coordinate = coordinate(from: object) ?? coordinate(from: rootObject)

    guard !object.isEmpty else {
      let placeholder = HomeDetailExifInfo.placeholder
      return HomeDetailExifInfo(
        device: placeholder.device,
        cameraLine: placeholder.cameraLine,
        fileLine: placeholder.fileLine,
        locationLine: coordinate.map { locationLine(for: $0) } ?? placeholder.locationLine,
        coordinate: coordinate
      )
    }

    let device = object.firstString(
      for: ["device", "model", "cameraModel", "camera_model", "make_model", "makeModel"],
      default: "Apple iPhone 16 Pro"
    )
    let lens = object.firstString(for: ["lens", "camera", "camera_type", "cameraType"], default: "와이드 카메라")
    let focalLength = object.firstString(for: ["focal_length", "focalLength", "focal"], default: "26 mm")
    let aperture = object.firstString(for: ["aperture", "f_number", "fNumber"], default: "1.5")
    let iso = object.firstString(for: ["iso", "ISO"], default: "400")
    let width = object.firstInt(for: ["width", "pixel_width", "pixelWidth"], default: 3024)
    let height = object.firstInt(for: ["height", "pixel_height", "pixelHeight"], default: 4032)
    let fileSize = object.firstString(for: ["file_size", "fileSize", "size"], default: "2.2MB")
    let location = object.firstString(
      for: ["address", "location", "location_name", "locationName", "place", "gps", "geo"]
    )

    return HomeDetailExifInfo(
      device: device,
      cameraLine: "\(lens) - \(focalLength) 𝒇 \(aperture) ISO \(iso)",
      fileLine: "12MP • \(width) × \(height) • \(fileSize)",
      locationLine: location ?? coordinate.map { locationLine(for: $0) },
      coordinate: coordinate
    )
  }

  nonisolated private static func coordinate(from object: [String: JSONValue]) -> HomeDetailCoordinate? {
    if let latitude = object.firstDouble(for: [
      "latitude",
      "lat",
      "gps_latitude",
      "gpsLatitude",
      "GPSLatitude"
    ]),
      let longitude = object.firstDouble(for: [
        "longitude",
        "lng",
        "lon",
        "long",
        "gps_longitude",
        "gpsLongitude",
        "GPSLongitude"
      ]),
      let coordinate = coordinate(latitude: latitude, longitude: longitude) {
      return coordinate
    }

    let nestedKeys = [
      "location",
      "gps",
      "geo",
      "geolocation",
      "coordinate",
      "coordinates",
      "photoMetadata",
      "photo_metadata",
      "metadata",
    ]

    for key in nestedKeys {
      if let nestedObject = object[key]?.objectValue,
         let coordinate = coordinate(from: nestedObject) {
        return coordinate
      }

      if let array = object[key]?.arrayValue,
         let coordinate = coordinate(
          from: array,
          prefersLongitudeFirst: key == "coordinates"
         ) {
        return coordinate
      }
    }

    return nil
  }

  nonisolated private static func coordinate(
    from array: [JSONValue],
    prefersLongitudeFirst: Bool
  ) -> HomeDetailCoordinate? {
    guard array.count >= 2,
          let first = array[0].doubleValue,
          let second = array[1].doubleValue else {
      return nil
    }

    if prefersLongitudeFirst,
       let coordinate = coordinate(latitude: second, longitude: first) {
      return coordinate
    }

    if let coordinate = coordinate(latitude: first, longitude: second) {
      return coordinate
    }

    return coordinate(latitude: second, longitude: first)
  }

  nonisolated private static func coordinate(latitude: Double, longitude: Double) -> HomeDetailCoordinate? {
    guard (-90...90).contains(latitude),
          (-180...180).contains(longitude) else {
      return nil
    }

    return HomeDetailCoordinate(latitude: latitude, longitude: longitude)
  }

  nonisolated private static func locationLine(for coordinate: HomeDetailCoordinate) -> String {
    String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
  }

  nonisolated private static func presets(from object: [String: JSONValue]) -> [HomeDetailPreset] {
    let definitions: [(String, String)] = [
      ("brightness", AppAsset.HomeDetail.presetBrightness),
      ("exposure", AppAsset.HomeDetail.presetExposure),
      ("contrast", AppAsset.HomeDetail.presetContrast),
      ("saturation", AppAsset.HomeDetail.presetSaturation),
      ("sharpness", AppAsset.HomeDetail.presetSharpness),
      ("blur", AppAsset.HomeDetail.presetBlur),
      ("vignette", AppAsset.HomeDetail.presetVignette),
      ("noise_reduction", AppAsset.HomeDetail.presetNoise),
      ("highlights", AppAsset.HomeDetail.presetHighlights),
      ("shadows", AppAsset.HomeDetail.presetShadows),
      ("temperature", AppAsset.HomeDetail.presetTemperature),
      ("black_point", AppAsset.HomeDetail.presetBlackPoint),
    ]

    let presets = definitions.compactMap { key, assetName -> HomeDetailPreset? in
      guard let value = object[key]?.doubleValue else { return nil }
      return HomeDetailPreset(
        id: key,
        assetName: assetName,
        value: formattedValue(value, key: key)
      )
    }

    return presets.isEmpty ? HomeDetailDesignData.defaultPresets : presets
  }

  nonisolated private static func formattedValue(_ value: Double, key: String) -> String {
    if key == "temperature" {
      return "\(Int(value.rounded()))"
    }

    return String(format: "%.1f", (value * 10).rounded() / 10)
  }

  nonisolated private static func imagePaths(from value: JSONValue?) -> [String] {
    guard let value else { return [] }

    if let string = value.stringValue?.trimmed, !string.isEmpty {
      return [string]
    }

    if let array = value.arrayValue {
      return array.flatMap { element -> [String] in
        if let string = element.stringValue?.trimmed, !string.isEmpty {
          return [string]
        }

        if let nestedArray = element.arrayValue {
          return nestedArray.compactMap { $0.stringValue?.trimmed }.filter { !$0.isEmpty }
        }

        if let object = element.objectValue,
           let path = object.firstString(for: ["path", "file", "url", "image", "image_url", "imageUrl"]) {
          return [path]
        }

        return []
      }
    }

    return []
  }

  nonisolated private static func containerObject(from value: JSONValue, preferredKeys: [String]) -> [String: JSONValue] {
    if let object = value.objectValue {
      for key in preferredKeys {
        if let nestedObject = object[key]?.objectValue {
          return nestedObject
        }
      }
      return object
    }

    return value.arrayValue?.first?.objectValue ?? [:]
  }
}

private extension JSONValue {
  nonisolated var objectValue: [String: JSONValue]? {
    guard case let .object(object) = self else { return nil }
    return object
  }

  nonisolated var arrayValue: [JSONValue]? {
    guard case let .array(array) = self else { return nil }
    return array
  }

  nonisolated var stringValue: String? {
    switch self {
    case let .string(value):
      return value
    case let .number(value):
      return String(Int(value))
    default:
      return nil
    }
  }

  nonisolated var intValue: Int? {
    switch self {
    case let .number(value):
      return Int(value)
    case let .string(value):
      return Int(value)
    default:
      return nil
    }
  }

  nonisolated var doubleValue: Double? {
    switch self {
    case let .number(value):
      return value
    case let .string(value):
      return Double(value)
    default:
      return nil
    }
  }

  nonisolated var boolValue: Bool? {
    switch self {
    case let .boolean(value):
      return value
    case let .string(value):
      return Bool(value)
    default:
      return nil
    }
  }
}

private extension Dictionary where Key == String, Value == JSONValue {
  nonisolated func firstString(for keys: [String], default fallback: String) -> String {
    firstString(for: keys) ?? fallback
  }

  nonisolated func firstString(for keys: [String]) -> String? {
    for key in keys {
      if let value = self[key]?.stringValue?.trimmed, !value.isEmpty {
        return value
      }
    }
    return nil
  }

  nonisolated func firstInt(for keys: [String], default fallback: Int) -> Int {
    for key in keys {
      if let value = self[key]?.intValue {
        return value
      }
    }
    return fallback
  }

  nonisolated func firstDouble(for keys: [String]) -> Double? {
    for key in keys {
      if let value = self[key]?.doubleValue {
        return value
      }
    }
    return nil
  }

  nonisolated func firstBool(for keys: [String], default fallback: Bool) -> Bool {
    for key in keys {
      if let value = self[key]?.boolValue {
        return value
      }
    }
    return fallback
  }

  nonisolated func tags() -> [String] {
    let values = self["hashTags"]?.arrayValue ?? self["hashtags"]?.arrayValue ?? self["tags"]?.arrayValue ?? []
    return values.compactMap { value in
      guard let tag = value.stringValue?.trimmed, !tag.isEmpty else { return nil }
      return tag.hasPrefix("#") ? tag : "#\(tag)"
    }
  }
}
