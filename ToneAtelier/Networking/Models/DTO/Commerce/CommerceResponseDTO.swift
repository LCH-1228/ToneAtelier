//
//  CommerceResponseDTO.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import Foundation

/// spec OrderCreateResponseDTO. 주문 생성 응답.
struct OrderCreateResponseDTO: nonisolated Decodable, Equatable, Sendable {
  let orderID: String
  let orderCode: String
  let totalPrice: Int
  let createdAt: String
  let updatedAt: String

  enum CodingKeys: String, CodingKey {
    case orderID = "order_id"
    case orderCode = "order_code"
    case totalPrice = "total_price"
    case createdAt, updatedAt
  }
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
  let filterValues: FilterValuesDTO?
  let createdAt: String?
  let updatedAt: String?

  enum CodingKeys: String, CodingKey {
    case id, category, title, description, files, price, creator
    case filterValues = "filter_values"
    case createdAt, updatedAt
  }
}

/// spec OrderResponseDTO. 주문 단건.
struct OrderResponseDTO: nonisolated Decodable, Equatable, Sendable {
  let orderID: String
  let orderCode: String
  let totalPrice: Int?
  let filter: FilterSummaryOrderResponseDTO?
  let paidAt: String?
  let createdAt: String
  let updatedAt: String

  enum CodingKeys: String, CodingKey {
    case orderID = "order_id"
    case orderCode = "order_code"
    case totalPrice = "total_price"
    case filter, paidAt, createdAt, updatedAt
  }
}

/// /v1/orders GET 응답. spec inline 정의(`{ data: OrderResponseDTO[] }`).
struct OrderListResponseDTO: nonisolated Decodable, Equatable, Sendable {
  let data: [OrderResponseDTO]
}

/// spec ReceiptOrderResponseDTO. 결제 검증 결과(영수증).
struct ReceiptOrderResponseDTO: nonisolated Decodable, Equatable, Sendable {
  let paymentID: String
  let orderItem: OrderResponseDTO?
  let createdAt: String
  let updatedAt: String

  enum CodingKeys: String, CodingKey {
    case paymentID = "payment_id"
    case orderItem = "order_item"
    case createdAt, updatedAt
  }
}

/// spec PaymentResponseDTO. 결제 영수증 상세(아임포트 응답을 그대로 따름).
/// 필드가 매우 많고 모두 optional이라 안전하게 모두 optional로 선언.
struct PaymentResponseDTO: nonisolated Decodable, Equatable, Sendable {
  let impUID: String
  let merchantUID: String
  let payMethod: String?
  let channel: String?
  let pgProvider: String?
  let embPgProvider: String?
  let pgTID: String?
  let pgID: String?
  let escrow: Bool?
  let applyNum: String?
  let bankCode: String?
  let bankName: String?
  let cardCode: String?
  let cardName: String?
  let cardIssuerCode: String?
  let cardIssuerName: String?
  let cardPublisherCode: String?
  let cardPublisherName: String?
  let cardQuota: Int?
  let cardNumber: String?
  let cardType: Int?
  let vbankCode: String?
  let vbankName: String?
  let vbankNum: String?
  let vbankHolder: String?
  let vbankDate: Int?
  let vbankIssuedAt: Int?
  let name: String?
  let amount: Int
  let currency: String
  let buyerName: String?
  let buyerEmail: String?
  let buyerTel: String?
  let buyerAddr: String?
  let buyerPostcode: String?
  let customData: String?
  let userAgent: String?
  let status: String
  let startedAt: String?
  let paidAt: String?
  let receiptURL: String?
  let createdAt: String?
  let updatedAt: String?

  enum CodingKeys: String, CodingKey {
    case impUID = "imp_uid"
    case merchantUID = "merchant_uid"
    case payMethod = "pay_method"
    case channel
    case pgProvider = "pg_provider"
    case embPgProvider = "emb_pg_provider"
    case pgTID = "pg_tid"
    case pgID = "pg_id"
    case escrow
    case applyNum = "apply_num"
    case bankCode = "bank_code"
    case bankName = "bank_name"
    case cardCode = "card_code"
    case cardName = "card_name"
    case cardIssuerCode = "card_issuer_code"
    case cardIssuerName = "card_issuer_name"
    case cardPublisherCode = "card_publisher_code"
    case cardPublisherName = "card_publisher_name"
    case cardQuota = "card_quota"
    case cardNumber = "card_number"
    case cardType = "card_type"
    case vbankCode = "vbank_code"
    case vbankName = "vbank_name"
    case vbankNum = "vbank_num"
    case vbankHolder = "vbank_holder"
    case vbankDate = "vbank_date"
    case vbankIssuedAt = "vbank_issued_at"
    case name, amount, currency
    case buyerName = "buyer_name"
    case buyerEmail = "buyer_email"
    case buyerTel = "buyer_tel"
    case buyerAddr = "buyer_addr"
    case buyerPostcode = "buyer_postcode"
    case customData = "custom_data"
    case userAgent = "user_agent"
    case status, startedAt, paidAt
    case receiptURL = "receipt_url"
    case createdAt, updatedAt
  }
}
