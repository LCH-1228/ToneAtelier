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
  let commentID: String
  let content: String
  let createdAt: String
  let creator: UserInfoResponseDTO

  enum CodingKeys: String, CodingKey {
    case commentID = "comment_id"
    case content, createdAt, creator
  }
}

/// spec PostCommentResponseDTO.
struct PostCommentResponseDTO: nonisolated Decodable, Equatable, Sendable {
  let commentID: String
  let content: String
  let createdAt: String
  let creator: UserInfoResponseDTO
  let replies: [PostCommentReplyDTO]

  enum CodingKeys: String, CodingKey {
    case commentID = "comment_id"
    case content, createdAt, creator, replies
  }
}

/// spec PostSummaryResponseDTO. 게시글 목록 카드용.
struct PostSummaryResponseDTO: nonisolated Decodable, Equatable, Sendable {
  let postID: String
  let category: String
  let title: String
  let content: String
  let geolocation: GeolocationDTO
  let creator: UserInfoResponseDTO
  let files: [String]
  let isLike: Bool
  let likeCount: Double
  let createdAt: String
  let updatedAt: String

  enum CodingKeys: String, CodingKey {
    case postID = "post_id"
    case category, title, content, geolocation, creator, files
    case isLike = "is_like"
    case likeCount = "like_count"
    case createdAt, updatedAt
  }
}

/// spec PostResponseDTO. 게시글 단건 상세.
struct PostResponseDTO: nonisolated Decodable, Equatable, Sendable {
  let postID: String
  let category: String
  let title: String
  let content: String
  let geolocation: GeolocationDTO
  let creator: UserInfoResponseDTO
  let files: [String]
  let isLike: Bool
  let likeCount: Double
  let comments: [PostCommentResponseDTO]
  let createdAt: String
  let updatedAt: String

  enum CodingKeys: String, CodingKey {
    case postID = "post_id"
    case category, title, content, geolocation, creator, files
    case isLike = "is_like"
    case likeCount = "like_count"
    case comments, createdAt, updatedAt
  }
}

/// spec PostSummaryPaginationResponseDTO.
struct PostSummaryPaginationResponseDTO: nonisolated Decodable, Equatable, Sendable {
  let data: [PostSummaryResponseDTO]
  let nextCursor: String?

  enum CodingKeys: String, CodingKey {
    case data
    case nextCursor = "next_cursor"
  }
}

/// spec PostSummaryListResponseDTO.
struct PostSummaryListResponseDTO: nonisolated Decodable, Equatable, Sendable {
  let data: [PostSummaryResponseDTO]
}
