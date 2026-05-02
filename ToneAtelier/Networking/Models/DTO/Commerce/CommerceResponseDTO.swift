//
//  CommerceResponseDTO.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import Foundation

/// spec OrderCreateResponseDTO. 주문 생성 응답.
struct OrderCreateResponseDTO: nonisolated Decodable, Equatable, Sendable {
  let order_id: String
  let order_code: String
  let total_price: Int
  let createdAt: String
  let updatedAt: String
}

/// 기존 호출부 호환을 위한 alias (CommonResponses의 OrderCreatedResponse 대체).
typealias OrderCreatedResponseDTO = OrderCreateResponseDTO

/// spec FilterSummaryResponseDTO_Order. 주문 내역에 포함되는 필터 요약 정보.
struct FilterSummaryOrderResponseDTO: nonisolated Decodable, Equatable, Sendable {
  let id: String?
  let category: String?
  let title: String?
  let description: String?
  let files: [String]?
  let price: Int?
  let creator: UserInfoResponseDTO?
  let filter_values: FilterValuesDTO?
  let createdAt: String?
  let updatedAt: String?
}

/// spec OrderResponseDTO. 주문 단건.
struct OrderResponseDTO: nonisolated Decodable, Equatable, Sendable {
  let order_id: String
  let order_code: String
  let total_price: Int?
  let filter: FilterSummaryOrderResponseDTO?
  let paidAt: String?
  let createdAt: String
  let updatedAt: String
}

/// /v1/orders GET 응답. spec inline 정의(`{ data: OrderResponseDTO[] }`).
struct OrderListResponseDTO: nonisolated Decodable, Equatable, Sendable {
  let data: [OrderResponseDTO]
}

/// spec ReceiptOrderResponseDTO. 결제 검증 결과(영수증).
struct ReceiptOrderResponseDTO: nonisolated Decodable, Equatable, Sendable {
  let payment_id: String
  let order_item: OrderResponseDTO?
  let createdAt: String
  let updatedAt: String
}

/// spec PaymentResponseDTO. 결제 영수증 상세(아임포트 응답을 그대로 따름).
/// 필드가 매우 많고 모두 optional이라 안전하게 모두 optional로 선언.
struct PaymentResponseDTO: nonisolated Decodable, Equatable, Sendable {
  let imp_uid: String
  let merchant_uid: String
  let pay_method: String?
  let channel: String?
  let pg_provider: String?
  let emb_pg_provider: String?
  let pg_tid: String?
  let pg_id: String?
  let escrow: Bool?
  let apply_num: String?
  let bank_code: String?
  let bank_name: String?
  let card_code: String?
  let card_name: String?
  let card_issuer_code: String?
  let card_issuer_name: String?
  let card_publisher_code: String?
  let card_publisher_name: String?
  let card_quota: Int?
  let card_number: String?
  let card_type: Int?
  let vbank_code: String?
  let vbank_name: String?
  let vbank_num: String?
  let vbank_holder: String?
  let vbank_date: Int?
  let vbank_issued_at: Int?
  let name: String?
  let amount: Int
  let currency: String
  let buyer_name: String?
  let buyer_email: String?
  let buyer_tel: String?
  let buyer_addr: String?
  let buyer_postcode: String?
  let custom_data: String?
  let user_agent: String?
  let status: String
  let startedAt: String?
  let paidAt: String?
  let receipt_url: String?
  let createdAt: String?
  let updatedAt: String?
}
