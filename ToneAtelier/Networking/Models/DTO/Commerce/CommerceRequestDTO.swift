//
//  CommerceRequestDTO.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import Foundation

struct OrderCreateRequestDTO: Encodable, Equatable, Sendable {
  let filter_id: String
  let total_price: Int
}

struct PaymentValidationRequestDTO: Encodable, Equatable, Sendable {
  let imp_uid: String
  let filter_id: String
}
