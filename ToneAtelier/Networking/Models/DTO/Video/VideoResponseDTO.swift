//
//  VideoResponseDTO.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import Foundation

/// spec VideoResponseDTO. HLS 기반 VOD 단건 메타데이터.
struct VideoResponseDTO: nonisolated Decodable, Equatable, Sendable {
  let videoID: String
  let fileName: String
  let title: String
  let description: String
  let duration: Double
  let thumbnailURL: String
  let availableQualities: [String]
  let viewCount: Int
  let likeCount: Int
  let isLiked: Bool
  let createdAt: String

  enum CodingKeys: String, CodingKey {
    case videoID = "video_id"
    case fileName = "file_name"
    case title, description, duration
    case thumbnailURL = "thumbnail_url"
    case availableQualities = "available_qualities"
    case viewCount = "view_count"
    case likeCount = "like_count"
    case isLiked = "is_liked"
    case createdAt
  }
}

/// spec VideoListResponseDTO. video 목록 + 페이지네이션 커서.
struct VideoListResponseDTO: nonisolated Decodable, Equatable, Sendable {
  let data: [VideoResponseDTO]
  let nextCursor: String?

  enum CodingKeys: String, CodingKey {
    case data
    case nextCursor = "next_cursor"
  }
}

/// spec StreamUrlResponseDTO.qualities 항목.
struct StreamQualityDTO: nonisolated Decodable, Equatable, Sendable {
  let quality: String
  let url: String
}

/// spec StreamUrlResponseDTO.subtitles 항목.
struct StreamSubtitleDTO: nonisolated Decodable, Equatable, Sendable {
  let language: String
  let name: String
  let isDefault: Bool
  let url: String

  enum CodingKeys: String, CodingKey {
    case language, name
    case isDefault = "is_default"
    case url
  }
}

/// spec StreamUrlResponseDTO. HLS 마스터 + 화질별 + 자막 URL.
struct StreamUrlResponseDTO: nonisolated Decodable, Equatable, Sendable {
  let videoID: String
  let streamURL: String
  let qualities: [StreamQualityDTO]
  let subtitles: [StreamSubtitleDTO]

  enum CodingKeys: String, CodingKey {
    case videoID = "video_id"
    case streamURL = "stream_url"
    case qualities, subtitles
  }
}
