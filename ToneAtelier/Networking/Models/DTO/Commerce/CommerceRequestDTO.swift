//
//  CommerceRequestDTO.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import Foundation

struct OrderCreateRequestDTO: Encodable, Equatable, Sendable {
  let filterID: String
  let totalPrice: Int

  enum CodingKeys: String, CodingKey {
    case filterID = "filter_id"
    case totalPrice = "total_price"
  }
}

struct PaymentValidationRequestDTO: Encodable, Equatable, Sendable {
  let impUID: String
  let filterID: String

  enum CodingKeys: String, CodingKey {
    case impUID = "imp_uid"
    case filterID = "filter_id"
  }
}
