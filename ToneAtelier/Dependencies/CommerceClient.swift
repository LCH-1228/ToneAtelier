//
//  CommerceClient.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import ComposableArchitecture
import Foundation

struct CreateOrderRequest: Encodable, Equatable, Sendable {
  let filter_id: String
  let total_price: Int
}

struct PaymentValidationRequest: Encodable, Equatable, Sendable {
  let imp_uid: String
}

struct CommerceClient {
  var createOrder: @Sendable (_ request: CreateOrderRequest) async throws -> OrderCreatedResponse
  var fetchOrders: @Sendable () async throws -> JSONValue
  var validatePayment: @Sendable (_ request: PaymentValidationRequest) async throws -> JSONValue
  var fetchPaymentReceipt: @Sendable (_ orderCode: String) async throws -> JSONValue
}

extension CommerceClient: DependencyKey {
  static var liveValue: CommerceClient {
    @Dependency(\.httpClient) var httpClient

    return CommerceClient(
      createOrder: { request in
        try await httpClient.send(
          APIEndpoint<OrderCreatedResponse>(router: CommerceRouter.createOrder(request))
        )
      },
      fetchOrders: {
        try await httpClient.send(
          APIEndpoint<JSONValue>(router: CommerceRouter.fetchOrders)
        )
      },
      validatePayment: { request in
        try await httpClient.send(
          APIEndpoint<JSONValue>(router: CommerceRouter.validatePayment(request))
        )
      },
      fetchPaymentReceipt: { orderCode in
        try await httpClient.send(
          APIEndpoint<JSONValue>(router: CommerceRouter.fetchPaymentReceipt(orderCode: orderCode))
        )
      }
    )
  }

  static let testValue = CommerceClient(
    createOrder: { _ in throw APIError.transport("CommerceClient.createOrder testValue") },
    fetchOrders: { throw APIError.transport("CommerceClient.fetchOrders testValue") },
    validatePayment: { _ in throw APIError.transport("CommerceClient.validatePayment testValue") },
    fetchPaymentReceipt: { _ in throw APIError.transport("CommerceClient.fetchPaymentReceipt testValue") }
  )
}

extension DependencyValues {
  var commerceClient: CommerceClient {
    get { self[CommerceClient.self] }
    set { self[CommerceClient.self] = newValue }
  }
}
