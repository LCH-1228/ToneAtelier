//
//  FilterResponseDTO.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import Foundation

// MARK: - Shared Filter DTOs

/// spec PhotoMetadataDTO.
struct PhotoMetadataDTO: nonisolated Codable, Equatable, Sendable {
  let camera: String?
  let lensInfo: String?
  let focalLength: Double?
  let aperture: Double?
  let iso: Int?
  let shutterSpeed: String?
  let pixelWidth: Int?
  let pixelHeight: Int?
  let fileSize: Double?
  let format: String?
  let dateTimeOriginal: String?
  let latitude: Double?
  let longitude: Double?

  enum CodingKeys: String, CodingKey {
    case camera
    case lensInfo = "lens_info"
    case focalLength = "focal_length"
    case aperture, iso
    case shutterSpeed = "shutter_speed"
    case pixelWidth = "pixel_width"
    case pixelHeight = "pixel_height"
    case fileSize = "file_size"
    case format
    case dateTimeOriginal = "date_time_original"
    case latitude, longitude
  }
}

/// spec FilterValuesDTO.
struct FilterValuesDTO: nonisolated Codable, Equatable, Sendable {
  let brightness: Double?
  let exposure: Double?
  let contrast: Double?
  let saturation: Double?
  let sharpness: Double?
  let blur: Double?
  let vignette: Double?
  let noiseReduction: Double?
  let highlights: Double?
  let shadows: Double?
  let temperature: Double?
  let blackPoint: Double?

  enum CodingKeys: String, CodingKey {
    case brightness, exposure, contrast, saturation, sharpness, blur, vignette
    case noiseReduction = "noise_reduction"
    case highlights, shadows, temperature
    case blackPoint = "black_point"
  }
}

// MARK: - Response DTOs

/// spec FilterCommentResponseDTO.replies 항목.
struct FilterCommentReplyDTO: nonisolated Decodable, Equatable, Sendable {
  let commentID: String
  let content: String
  let createdAt: String
  let creator: UserInfoResponseDTO

  enum CodingKeys: String, CodingKey {
    case commentID = "comment_id"
    case content, createdAt, creator
  }
}

/// spec FilterCommentResponseDTO.
struct FilterCommentResponseDTO: nonisolated Decodable, Equatable, Sendable {
  let commentID: String
  let content: String
  let createdAt: String
  let creator: UserInfoResponseDTO
  let replies: [FilterCommentReplyDTO]

  enum CodingKeys: String, CodingKey {
    case commentID = "comment_id"
    case content, createdAt, creator, replies
  }
}

/// spec FilterResponseDTO. 필터 단건 상세.
struct FilterResponseDTO: nonisolated Decodable, Equatable, Sendable {
  let filterID: String
  let category: String
  let title: String
  let description: String
  let files: [String]
  let price: Int?
  let creator: UserInfoResponseDTO
  let photoMetadata: PhotoMetadataDTO?
  let filterValues: FilterValuesDTO
  let isLiked: Bool
  let isDownloaded: Bool
  let likeCount: Int
  let buyerCount: Int
  let comments: [FilterCommentResponseDTO]
  let createdAt: String
  let updatedAt: String

  enum CodingKeys: String, CodingKey {
    case filterID = "filter_id"
    case category, title, description, files, price, creator, photoMetadata, filterValues
    case isLiked = "is_liked"
    case isDownloaded = "is_downloaded"
    case likeCount = "like_count"
    case buyerCount = "buyer_count"
    case comments, createdAt, updatedAt
  }
}

/// spec FilterSummaryResponseDTO. 목록/카드용 필터 요약.
struct FilterSummaryResponseDTO: nonisolated Decodable, Equatable, Sendable {
  let filterID: String
  let category: String?
  let title: String
  let description: String
  let files: [String]
  let creator: UserInfoResponseDTO
  let isLiked: Bool
  let likeCount: Int
  let buyerCount: Int
  let createdAt: String
  let updatedAt: String

  enum CodingKeys: String, CodingKey {
    case filterID = "filter_id"
    case category, title, description, files, creator
    case isLiked = "is_liked"
    case likeCount = "like_count"
    case buyerCount = "buyer_count"
    case createdAt, updatedAt
  }
}

/// spec FilterSummaryPaginationListResponseDTO. /v1/filters GET, /v1/filters/users/{user_id} 등.
struct FilterSummaryPaginationListResponseDTO: nonisolated Decodable, Equatable, Sendable {
  let data: [FilterSummaryResponseDTO]
  let nextCursor: String?

  enum CodingKeys: String, CodingKey {
    case data
    case nextCursor = "next_cursor"
  }
}

/// spec FilterSummaryListResponseDTO.
struct FilterSummaryListResponseDTO: nonisolated Decodable, Equatable, Sendable {
  let data: [FilterSummaryResponseDTO]
}

/// spec FilterGeoListResponseDTO. (likes/me 등 hot-trend 외 단순 list)
struct FilterGeoListResponseDTO: nonisolated Decodable, Equatable, Sendable {
  let data: [FilterResponseDTO]
}

/// spec TodayFilterResponseDTO. 오늘의 필터.
struct TodayFilterResponseDTO: nonisolated Decodable, Equatable, Sendable {
  let filterID: String
  let title: String
  let introduction: String?
  let description: String
  let files: [String]
  let createdAt: String
  let updatedAt: String

  enum CodingKeys: String, CodingKey {
    case filterID = "filter_id"
    case title, introduction, description, files, createdAt, updatedAt
  }
}

/// spec TodayAuthorResponseDTO. 오늘의 작가 + 작가의 필터 요약.
struct TodayAuthorResponseDTO: nonisolated Decodable, Equatable, Sendable {
  let author: TodayAuthorInfoResponseDTO
  let filters: [FilterSummaryResponseDTO]
}
