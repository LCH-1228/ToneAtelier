//
//  PurchaseHistoryFeature.swift
//  ToneAtelier
//
//  Created by Codex on 5/2/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct PurchaseHistoryFeature {
  @Dependency(\.commerceClient) var commerceClient

  @ObservableState
  struct State: Equatable {
    var orders: [OrderResponseDTO] = []
    var isLoading = false
    var hasLoaded = false
    var errorMessage: String?
    /// 영수증 sheet — 선택된 주문의 orderCode와 로딩 상태를 함께 보관.
    var receipt: ReceiptState?
  }

  struct ReceiptState: Equatable {
    var order: OrderResponseDTO
    var isLoading: Bool
    var payment: PaymentResponseDTO?
    var errorMessage: String?
  }

  enum Action: Sendable {
    case task
    case retryButtonTapped
    case ordersResponse(Result<[OrderResponseDTO], Error>)
    case orderTapped(orderID: String)
    case receiptResponse(Result<PaymentResponseDTO, Error>)
    case receiptDismissed
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .task:
        guard !state.isLoading, !state.hasLoaded else { return .none }
        return load(into: &state)

      case .retryButtonTapped:
        guard !state.isLoading else { return .none }
        return load(into: &state)

      case let .ordersResponse(.success(orders)):
        state.isLoading = false
        state.hasLoaded = true
        state.errorMessage = nil
        // 최근 주문이 위로 오도록 createdAt 내림차순 정렬.
        state.orders = orders.sorted { $0.createdAt > $1.createdAt }
        return .none

      case let .ordersResponse(.failure(error)):
        state.isLoading = false
        state.hasLoaded = true
        state.errorMessage = error.userFacingMessage
        return .none

      case let .orderTapped(orderID):
        guard let order = state.orders.first(where: { $0.orderID == orderID }) else { return .none }
        state.receipt = ReceiptState(order: order, isLoading: true, payment: nil, errorMessage: nil)
        let commerceClient = self.commerceClient
        let orderCode = order.orderCode
        return .run { send in
          await send(
            .receiptResponse(Result { try await commerceClient.fetchPaymentReceipt(orderCode) })
          )
        }
        .cancellable(id: CancelID.receipt, cancelInFlight: true)

      case let .receiptResponse(.success(payment)):
        guard state.receipt != nil else { return .none }
        state.receipt?.isLoading = false
        state.receipt?.payment = payment
        state.receipt?.errorMessage = nil
        return .none

      case let .receiptResponse(.failure(error)):
        guard state.receipt != nil else { return .none }
        state.receipt?.isLoading = false
        state.receipt?.errorMessage = error.userFacingMessage
        return .none

      case .receiptDismissed:
        state.receipt = nil
        return .cancel(id: CancelID.receipt)
      }
    }
  }

  private func load(into state: inout State) -> Effect<Action> {
    state.isLoading = true
    state.errorMessage = nil
    let commerceClient = self.commerceClient
    return .run { send in
      do {
        let response = try await commerceClient.fetchOrders()
        await send(.ordersResponse(.success(response.data)))
      } catch {
        await send(.ordersResponse(.failure(error)))
      }
    }
    .cancellable(id: CancelID.load, cancelInFlight: true)
  }
}

nonisolated private enum CancelID: Hashable, Sendable {
  case load
  case receipt
}

// MARK: - Error Mapping

private extension Error {
  var userFacingMessage: String {
    if let apiError = self as? APIError {
      switch apiError {
      case let .invalidBaseURL(message),
           let .invalidURL(message),
           let .transport(message),
           let .decoding(message):
        return message
      case .missingAccessToken, .missingRefreshToken:
        return "인증 정보가 없어 구매 내역을 불러올 수 없어요."
      case let .invalidSession(statusCode):
        return "세션이 유효하지 않습니다. 다시 로그인해 주세요. (\(statusCode))"
      case let .server(statusCode, message, _):
        if let message, !message.isEmpty { return message }
        return "서버 응답을 불러오지 못했어요. (\(statusCode))"
      }
    }
    return "구매 내역을 불러오지 못했어요. 잠시 후 다시 시도해 주세요."
  }
}
