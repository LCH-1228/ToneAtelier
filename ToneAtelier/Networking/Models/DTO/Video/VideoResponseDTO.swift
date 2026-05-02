//
//  VideoResponseDTO.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import Foundation

/// spec VideoResponseDTO. HLS 기반 VOD 단건 메타데이터.
struct VideoResponseDTO: nonisolated Decodable, Equatable, Sendable {
  let video_id: String
  let file_name: String
  let title: String
  let description: String
  let duration: Double
  let thumbnail_url: String
  let available_qualities: [String]
  let view_count: Int
  let like_count: Int
  let is_liked: Bool
  let createdAt: String
}

/// spec VideoListResponseDTO. video 목록 + 페이지네이션 커서.
struct VideoListResponseDTO: nonisolated Decodable, Equatable, Sendable {
  let data: [VideoResponseDTO]
  let next_cursor: String?
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
  let is_default: Bool
  let url: String
}

/// spec StreamUrlResponseDTO. HLS 마스터 + 화질별 + 자막 URL.
struct StreamUrlResponseDTO: nonisolated Decodable, Equatable, Sendable {
  let video_id: String
  let stream_url: String
  let qualities: [StreamQualityDTO]
  let subtitles: [StreamSubtitleDTO]
}
