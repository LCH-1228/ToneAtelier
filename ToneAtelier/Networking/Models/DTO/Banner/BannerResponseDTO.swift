//
//  BannerResponseDTO.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import Foundation

/// spec BannerDTO.payload — type/value 조합으로 진입 동작을 표현.
struct BannerPayloadDTO: nonisolated Decodable, Equatable, Sendable {
  let type: String
  let value: String
}

/// spec BannerDTO.
struct BannerDTO: nonisolated Decodable, Equatable, Sendable {
  let name: String
  let imageUrl: String
  let payload: BannerPayloadDTO
}

/// spec BannerListResponseDTO.
struct BannerListResponseDTO: nonisolated Decodable, Equatable, Sendable {
  let data: [BannerDTO]
}
