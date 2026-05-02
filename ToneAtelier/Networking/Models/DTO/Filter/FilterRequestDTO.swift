//
//  FilterRequestDTO.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import Foundation

/// spec FilterRequestDTO. 필터 생성 요청.
struct FilterRequestDTO: Encodable, Equatable, Sendable {
  let category: String
  let title: String
  let price: Int
  let description: String
  let files: [String]
  let photoMetadata: PhotoMetadataDTO?
  let filterValues: FilterValuesDTO

  enum CodingKeys: String, CodingKey {
    case category, title, price, description, files
    case photoMetadata = "photo_metadata"
    case filterValues = "filter_values"
  }
}

/// spec FilterUpdateRequestDTO. 필터 수정 요청. 모두 optional.
struct FilterUpdateRequestDTO: Encodable, Equatable, Sendable {
  let category: String?
  let title: String?
  let price: Int?
  let description: String?
  let files: [String]?
  let photoMetadata: PhotoMetadataDTO?
  let filterValues: FilterValuesDTO?

  enum CodingKeys: String, CodingKey {
    case category, title, price, description, files
    case photoMetadata = "photo_metadata"
    case filterValues = "filter_values"
  }
}

struct CommentRequestDTO: Encodable, Equatable, Sendable {
  let parentCommentID: String?
  let content: String

  enum CodingKeys: String, CodingKey {
    case parentCommentID = "parent_comment_id"
    case content
  }
}

struct CommentUpdateRequestDTO: Encodable, Equatable, Sendable {
  let content: String
}
