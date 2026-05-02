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
  let photo_metadata: PhotoMetadataDTO?
  let filter_values: FilterValuesDTO
}

/// spec FilterUpdateRequestDTO. 필터 수정 요청. 모두 optional.
struct FilterUpdateRequestDTO: Encodable, Equatable, Sendable {
  let category: String?
  let title: String?
  let price: Int?
  let description: String?
  let files: [String]?
  let photo_metadata: PhotoMetadataDTO?
  let filter_values: FilterValuesDTO?
}

struct CommentRequestDTO: Encodable, Equatable, Sendable {
  let parent_comment_id: String?
  let content: String
}

struct CommentUpdateRequestDTO: Encodable, Equatable, Sendable {
  let content: String
}
