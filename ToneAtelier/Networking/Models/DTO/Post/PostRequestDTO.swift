//
//  PostRequestDTO.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import Foundation

/// spec PostRequestDTO. 게시글 생성. files는 spec에서 옵셔널.
struct PostRequestDTO: Encodable, Equatable, Sendable {
  let category: String
  let title: String
  let content: String
  let latitude: Double
  let longitude: Double
  let files: [String]?
}

/// spec PostUpdateRequestDTO. 모두 옵셔널.
struct PostUpdateRequestDTO: Encodable, Equatable, Sendable {
  let category: String?
  let title: String?
  let content: String?
  let latitude: Double?
  let longitude: Double?
  let files: [String]?
}
