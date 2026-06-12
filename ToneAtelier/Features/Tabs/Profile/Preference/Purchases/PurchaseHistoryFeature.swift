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
  @Dependency(\.paymentReceiptStore) var paymentReceiptStore

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
    /// 결제 직후 검증 전 앱 종료된 영수증의 자동 재검증 결과.
    /// 성공한 merchantUID 는 store 에서 제거하고 주문 목록을 새로 조회한다.
    case reconcileFinished(succeededMerchantUIDs: [String])
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .task:
        guard !state.hasLoaded else { return .none }
        return load(into: &state)

      case .retryButtonTapped:
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

      case let .reconcileFinished(succeededMerchantUIDs):
        // 자동 재검증으로 정산된 주문이 있다면 주문 목록을 새로 조회해 반영.
        // 실패 케이스는 silent — 24h 후 PaymentReceiptStore 가 자동 prune.
        guard !succeededMerchantUIDs.isEmpty else { return .none }
        return refetchOrders()
      }
    }
  }

  private func load(into state: inout State) -> Effect<Action> {
    state.isLoading = true
    state.errorMessage = nil
    return .merge(
      fetchOrdersEffect(),
      reconcileEffect()
    )
  }

  /// 진행 중인 영수증을 재검증하고, 성공한 merchantUID 만 모아 단일 액션으로 보고.
  /// 각 receipt 호출은 병렬 (`withTaskGroup`) — 미완이 여러 건이어도 빠르게 처리.
  private func reconcileEffect() -> Effect<Action> {
    let commerceClient = self.commerceClient
    let paymentReceiptStore = self.paymentReceiptStore
    return .run { send in
      let receipts = await paymentReceiptStore.loadAll()
      let pending = receipts.compactMap { receipt -> (String, String, String)? in
        guard let impUID = receipt.impUID else { return nil }
        return (receipt.merchantUID, impUID, receipt.filterID)
      }
      guard !pending.isEmpty else { return }

      let succeeded = await withTaskGroup(of: String?.self) { group in
        for (merchantUID, impUID, filterID) in pending {
          group.addTask {
            do {
              _ = try await commerceClient.validatePayment(
                PaymentValidationRequestDTO(impUID: impUID, filterID: filterID)
              )
              await paymentReceiptStore.remove(merchantUID)
              return merchantUID
            } catch {
              return nil
            }
          }
        }
        var results: [String] = []
        for await result in group {
          if let merchantUID = result {
            results.append(merchantUID)
          }
        }
        return results
      }
      await send(.reconcileFinished(succeededMerchantUIDs: succeeded))
    }
    .cancellable(id: CancelID.reconcile, cancelInFlight: true)
  }

  private func fetchOrdersEffect() -> Effect<Action> {
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

  /// reconcile 성공 후 주문 목록만 재조회 (isLoading 변경 없음 — 사용자 인지 불필요).
  private func refetchOrders() -> Effect<Action> {
    fetchOrdersEffect()
  }
}

nonisolated private enum CancelID: Hashable, Sendable {
  case load
  case receipt
  case reconcile
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
