//
//  CommerceClient.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import ComposableArchitecture
import Foundation

struct CommerceClient {
  var createOrder: @Sendable (_ request: OrderCreateRequestDTO) async throws -> OrderCreateResponseDTO
  var fetchOrders: @Sendable () async throws -> OrderListResponseDTO
  var validatePayment: @Sendable (_ request: PaymentValidationRequestDTO) async throws -> ReceiptOrderResponseDTO
  var fetchPaymentReceipt: @Sendable (_ orderCode: String) async throws -> PaymentResponseDTO
}

extension CommerceClient: DependencyKey {
  static var liveValue: CommerceClient {
    @Dependency(\.httpClient) var httpClient

    return CommerceClient(
      createOrder: { request in
        try await httpClient.send(
          APIEndpoint<OrderCreateResponseDTO>(router: CommerceRouter.createOrder(request))
        )
      },
      fetchOrders: {
        try await httpClient.send(
          APIEndpoint<OrderListResponseDTO>(router: CommerceRouter.fetchOrders)
        )
      },
      validatePayment: { request in
        try await httpClient.send(
          APIEndpoint<ReceiptOrderResponseDTO>(router: CommerceRouter.validatePayment(request))
        )
      },
      fetchPaymentReceipt: { orderCode in
        try await httpClient.send(
          APIEndpoint<PaymentResponseDTO>(router: CommerceRouter.fetchPaymentReceipt(orderCode: orderCode))
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
