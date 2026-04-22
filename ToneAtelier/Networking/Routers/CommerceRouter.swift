//
//  CommerceRouter.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import Foundation

enum CommerceRouter: APIRouter {
  case createOrder(CreateOrderRequest)
  case fetchOrders
  case validatePayment(PaymentValidationRequest)
  case fetchPaymentReceipt(orderCode: String)

  var method: HTTPMethod {
    switch self {
    case .createOrder, .validatePayment:
      return .post
    case .fetchOrders, .fetchPaymentReceipt:
      return .get
    }
  }

  var path: String {
    switch self {
    case .createOrder, .fetchOrders: return APIInfo.Path.orders
    case .validatePayment: return APIInfo.Path.paymentsValidation
    case let .fetchPaymentReceipt(orderCode): return "\(APIInfo.Path.payments)/\(orderCode)"
    }
  }

  var body: HTTPBody {
    get throws {
      switch self {
      case let .createOrder(request): return try .jsonBody(request)
      case let .validatePayment(request): return try .jsonBody(request)
      default: return .none
      }
    }
  }

  var requiresAccessToken: Bool { true }
}
