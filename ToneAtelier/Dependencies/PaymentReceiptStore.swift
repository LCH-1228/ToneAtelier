//
//  PaymentReceiptStore.swift
//  ToneAtelier
//
//  Created by Codex on 5/9/26.
//

import ComposableArchitecture
import Foundation

/// 결제 시도/실패의 영수증 정보(merchantUID, impUID, filterID, 시각).
/// `validatePayment` 가 네트워크/서버 장애로 실패해 "카드는 결제됐는데 앱은 실패" 케이스가 발생할 때
/// 사용자가 고객 문의 시 첨부할 정보, 그리고 reconcile 재시도의 source.
struct PaymentReceipt: Codable, Equatable, Sendable {
  let merchantUID: String
  let impUID: String?
  let filterID: String
  let createdAt: Date
}

/// 결제 영수증의 in-flight / 미완 상태를 UserDefaults 에 저장한다.
/// - 로그아웃/세션 만료 시 `clearAll()` 로 비움 (다른 사용자에게 잔존 방지).
/// - 24h 이상 경과 entry 는 prune.
struct PaymentReceiptStore: Sendable {
  /// 결제 시작 시점에 기록.
  var record: @Sendable (_ receipt: PaymentReceipt) async -> Void
  /// 모든 미완 entry. prune 후 반환.
  var loadAll: @Sendable () async -> [PaymentReceipt]
  /// 특정 merchantUID 제거 (검증 성공/사용자 명시적 처리 시).
  var remove: @Sendable (_ merchantUID: String) async -> Void
  /// 로그아웃/세션 만료 시 호출.
  var clearAll: @Sendable () async -> Void
}

extension PaymentReceiptStore: DependencyKey {
  /// 24h 이상 경과 entry 는 의미 없음 — 다음 access 시 자동 prune.
  nonisolated private static let ttl: TimeInterval = 60 * 60 * 24
  nonisolated private static let storageKey = "payment.receipts"

  static let liveValue: PaymentReceiptStore = {
    PaymentReceiptStore(
      record: { receipt in
        var current = readAndPrune()
        current.removeAll { $0.merchantUID == receipt.merchantUID }
        current.append(receipt)
        write(current)
      },
      loadAll: {
        readAndPrune()
      },
      remove: { merchantUID in
        var current = readAndPrune()
        current.removeAll { $0.merchantUID == merchantUID }
        write(current)
      },
      clearAll: {
        UserDefaults.standard.removeObject(forKey: storageKey)
      }
    )
  }()

  static let testValue = PaymentReceiptStore(
    record: { _ in },
    loadAll: { [] },
    remove: { _ in },
    clearAll: {}
  )

  nonisolated private static func readAndPrune() -> [PaymentReceipt] {
    guard let raw = UserDefaults.standard.data(forKey: storageKey),
          let decoded = try? JSONDecoder().decode([PaymentReceipt].self, from: raw) else {
      return []
    }
    let cutoff = Date().addingTimeInterval(-ttl)
    let pruned = decoded.filter { $0.createdAt >= cutoff }
    if pruned.count != decoded.count {
      write(pruned)
    }
    return pruned
  }

  nonisolated private static func write(_ receipts: [PaymentReceipt]) {
    if receipts.isEmpty {
      UserDefaults.standard.removeObject(forKey: storageKey)
      return
    }
    if let encoded = try? JSONEncoder().encode(receipts) {
      UserDefaults.standard.set(encoded, forKey: storageKey)
    }
  }
}

extension DependencyValues {
  var paymentReceiptStore: PaymentReceiptStore {
    get { self[PaymentReceiptStore.self] }
    set { self[PaymentReceiptStore.self] = newValue }
  }
}
