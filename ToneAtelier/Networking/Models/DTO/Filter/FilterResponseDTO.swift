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
  let lens_info: String?
  let focal_length: Double?
  let aperture: Double?
  let iso: Int?
  let shutter_speed: String?
  let pixel_width: Int?
  let pixel_height: Int?
  let file_size: Double?
  let format: String?
  let date_time_original: String?
  let latitude: Double?
  let longitude: Double?
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
  let noise_reduction: Double?
  let highlights: Double?
  let shadows: Double?
  let temperature: Double?
  let black_point: Double?
}

// MARK: - Response DTOs

/// spec FilterCommentResponseDTO.replies 항목.
struct FilterCommentReplyDTO: nonisolated Decodable, Equatable, Sendable {
  let comment_id: String
  let content: String
  let createdAt: String
  let creator: UserInfoResponseDTO
}

/// spec FilterCommentResponseDTO.
struct FilterCommentResponseDTO: nonisolated Decodable, Equatable, Sendable {
  let comment_id: String
  let content: String
  let createdAt: String
  let creator: UserInfoResponseDTO
  let replies: [FilterCommentReplyDTO]
}

/// spec FilterResponseDTO. 필터 단건 상세.
struct FilterResponseDTO: nonisolated Decodable, Equatable, Sendable {
  let filter_id: String
  let category: String
  let title: String
  let description: String
  let files: [String]
  let price: Int?
  let creator: UserInfoResponseDTO
  let photoMetadata: PhotoMetadataDTO?
  let filterValues: FilterValuesDTO
  let is_liked: Bool
  let is_downloaded: Bool
  let like_count: Int
  let buyer_count: Int
  let comments: [FilterCommentResponseDTO]
  let createdAt: String
  let updatedAt: String
}

/// spec FilterSummaryResponseDTO. 목록/카드용 필터 요약.
struct FilterSummaryResponseDTO: nonisolated Decodable, Equatable, Sendable {
  let filter_id: String
  let category: String?
  let title: String
  let description: String
  let files: [String]
  let creator: UserInfoResponseDTO
  let is_liked: Bool
  let like_count: Int
  let buyer_count: Int
  let createdAt: String
  let updatedAt: String
}

/// spec FilterSummaryPaginationListResponseDTO. /v1/filters GET, /v1/filters/users/{user_id} 등.
struct FilterSummaryPaginationListResponseDTO: nonisolated Decodable, Equatable, Sendable {
  let data: [FilterSummaryResponseDTO]
  let next_cursor: String?
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
  let filter_id: String
  let title: String
  let introduction: String?
  let description: String
  let files: [String]
  let createdAt: String
  let updatedAt: String
}

/// spec TodayAuthorResponseDTO. 오늘의 작가 + 작가의 필터 요약.
struct TodayAuthorResponseDTO: nonisolated Decodable, Equatable, Sendable {
  let author: TodayAuthorInfoResponseDTO
  let filters: [FilterSummaryResponseDTO]
}
