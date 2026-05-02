//
//  PostResponseDTO.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import Foundation

/// spec Geolocation. 게시글 위치 좌표.
struct GeolocationDTO: nonisolated Decodable, Equatable, Sendable {
  let longitude: Double
  let latitude: Double
}

/// spec PostCommentResponseDTO.replies 항목.
struct PostCommentReplyDTO: nonisolated Decodable, Equatable, Sendable {
  let comment_id: String
  let content: String
  let createdAt: String
  let creator: UserInfoResponseDTO
}

/// spec PostCommentResponseDTO.
struct PostCommentResponseDTO: nonisolated Decodable, Equatable, Sendable {
  let comment_id: String
  let content: String
  let createdAt: String
  let creator: UserInfoResponseDTO
  let replies: [PostCommentReplyDTO]
}

/// spec PostSummaryResponseDTO. 게시글 목록 카드용.
struct PostSummaryResponseDTO: nonisolated Decodable, Equatable, Sendable {
  let post_id: String
  let category: String
  let title: String
  let content: String
  let geolocation: GeolocationDTO
  let creator: UserInfoResponseDTO
  let files: [String]
  let is_like: Bool
  let like_count: Double
  let createdAt: String
  let updatedAt: String
}

/// spec PostResponseDTO. 게시글 단건 상세.
struct PostResponseDTO: nonisolated Decodable, Equatable, Sendable {
  let post_id: String
  let category: String
  let title: String
  let content: String
  let geolocation: GeolocationDTO
  let creator: UserInfoResponseDTO
  let files: [String]
  let is_like: Bool
  let like_count: Double
  let comments: [PostCommentResponseDTO]
  let createdAt: String
  let updatedAt: String
}

/// spec PostSummaryPaginationResponseDTO.
struct PostSummaryPaginationResponseDTO: nonisolated Decodable, Equatable, Sendable {
  let data: [PostSummaryResponseDTO]
  let next_cursor: String?
}

/// spec PostSummaryListResponseDTO.
struct PostSummaryListResponseDTO: nonisolated Decodable, Equatable, Sendable {
  let data: [PostSummaryResponseDTO]
}
