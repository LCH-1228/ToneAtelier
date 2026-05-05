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
        try await filterClient.setLike(filterID, likeStatus).likeStatus
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
  nonisolated static func loadedData(from dto: FilterResponseDTO) -> HomeDetailLoadedData {
    let creator = dto.creator
    let files = dto.files
    let title = dto.title.trimmed.nilIfEmpty ?? "청록새록"
    let description = dto.description.trimmed.nilIfEmpty
    let authorNick = creator.nick.trimmed.nilIfEmpty ?? "윤새싹"
    let authorName = authorNick.uppercased()
    let authorSubtitle = creator.name?.trimmed.nilIfEmpty
      ?? creator.introduction?.trimmed.nilIfEmpty
      ?? "SESAC YOON"
    let authorTags = (creator.hashTags ?? [])
      .compactMap { $0.trimmed.nilIfEmpty }
      .map { $0.hasPrefix("#") ? $0 : "#\($0)" }

    return HomeDetailLoadedData(
      title: title,
      description: description,
      price: dto.price ?? 0,
      buyerCount: dto.buyerCount,
      likeCount: dto.likeCount,
      isLiked: dto.isLiked,
      isPurchased: dto.isDownloaded,
      afterImageURL: files.dropFirst().first ?? files.first,
      beforeImageURL: files.first,
      authorName: authorName,
      authorSubtitle: authorSubtitle,
      authorProfileImageURL: creator.profileImage?.trimmed.nilIfEmpty,
      authorTags: authorTags.isEmpty ? ["#섬세함", "#자연", "#미니멀"] : authorTags,
      exif: exifInfo(from: dto.photoMetadata),
      presets: presets(from: dto.filterValues),
      comments: dto.comments
    )
  }

  nonisolated private static func exifInfo(from metadata: PhotoMetadataDTO?) -> HomeDetailExifInfo {
    let coordinate: HomeDetailCoordinate? = {
      guard let lat = metadata?.latitude, let lng = metadata?.longitude,
            (-90...90).contains(lat), (-180...180).contains(lng) else { return nil }
      return HomeDetailCoordinate(latitude: lat, longitude: lng)
    }()

    guard let metadata else {
      let placeholder = HomeDetailExifInfo.placeholder
      return HomeDetailExifInfo(
        device: placeholder.device,
        cameraLine: placeholder.cameraLine,
        fileLine: placeholder.fileLine,
        locationLine: coordinate.map { locationLine(for: $0) } ?? placeholder.locationLine,
        coordinate: coordinate
      )
    }

    let device = metadata.camera?.trimmed.nilIfEmpty ?? "Apple iPhone 16 Pro"
    let lens = metadata.lensInfo?.trimmed.nilIfEmpty ?? "와이드 카메라"
    let focalLength = metadata.focalLength.map { String(format: "%.0f mm", $0) } ?? "26 mm"
    let aperture = metadata.aperture.map { String(format: "%.1f", $0) } ?? "1.5"
    let iso = metadata.iso.map(String.init) ?? "400"
    let width = metadata.pixelWidth ?? 3024
    let height = metadata.pixelHeight ?? 4032
    let fileSize = metadata.fileSize.map { Self.formatFileSize($0) } ?? "2.2MB"

    return HomeDetailExifInfo(
      device: device,
      cameraLine: "\(lens) - \(focalLength) 𝒇 \(aperture) ISO \(iso)",
      fileLine: "12MP • \(width) × \(height) • \(fileSize)",
      locationLine: coordinate.map { locationLine(for: $0) },
      coordinate: coordinate
    )
  }

  nonisolated private static func formatFileSize(_ bytes: Double) -> String {
    let mb = bytes / (1024 * 1024)
    return String(format: "%.1fMB", mb)
  }

  nonisolated private static func locationLine(for coordinate: HomeDetailCoordinate) -> String {
    String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
  }

  nonisolated private static func presets(from values: FilterValuesDTO) -> [HomeDetailPreset] {
    let definitions: [(String, String, Double?)] = [
      ("brightness", AppAsset.HomeDetail.presetBrightness, values.brightness),
      ("exposure", AppAsset.HomeDetail.presetExposure, values.exposure),
      ("contrast", AppAsset.HomeDetail.presetContrast, values.contrast),
      ("saturation", AppAsset.HomeDetail.presetSaturation, values.saturation),
      ("sharpness", AppAsset.HomeDetail.presetSharpness, values.sharpness),
      ("blur", AppAsset.HomeDetail.presetBlur, values.blur),
      ("vignette", AppAsset.HomeDetail.presetVignette, values.vignette),
      ("noise_reduction", AppAsset.HomeDetail.presetNoise, values.noiseReduction),
      ("highlights", AppAsset.HomeDetail.presetHighlights, values.highlights),
      ("shadows", AppAsset.HomeDetail.presetShadows, values.shadows),
      ("temperature", AppAsset.HomeDetail.presetTemperature, values.temperature),
      ("black_point", AppAsset.HomeDetail.presetBlackPoint, values.blackPoint)
    ]

    let presets = definitions.compactMap { key, assetName, value -> HomeDetailPreset? in
      guard let value else { return nil }
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
}

private extension String {
  nonisolated var nilIfEmpty: String? { isEmpty ? nil : self }
}
