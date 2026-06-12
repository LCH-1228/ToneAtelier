//
//  NetworkReachability.swift
//  ToneAtelier
//

import Foundation
import Network

/// connectivity 가 unsatisfied → satisfied 로 회복되는 시점을 yield.
/// 결제 영수증 재검증 등 "네트워크 복구 시 한 번 더 시도" 흐름의 트리거.
actor NetworkReachability {
  static let shared = NetworkReachability()

  private var continuations: [UUID: AsyncStream<Void>.Continuation] = [:]
  private var monitor: NWPathMonitor?
  private var lastWasSatisfied = true

  func recoveries() -> AsyncStream<Void> {
    let stream = AsyncStream.makeStream(of: Void.self)
    let id = UUID()
    continuations[id] = stream.continuation
    stream.continuation.onTermination = { [weak self] _ in
      Task { await self?.remove(id: id) }
    }
    startIfNeeded()
    return stream.stream
  }

  private func startIfNeeded() {
    guard monitor == nil else { return }
    let pathMonitor = NWPathMonitor()
    pathMonitor.pathUpdateHandler = { [weak self] path in
      Task { await self?.handle(status: path.status) }
    }
    pathMonitor.start(queue: DispatchQueue.global(qos: .background))
    monitor = pathMonitor
  }

  private func handle(status: NWPath.Status) {
    let isSatisfied = status == .satisfied
    if isSatisfied, !lastWasSatisfied {
      for continuation in continuations.values {
        continuation.yield()
      }
    }
    lastWasSatisfied = isSatisfied
  }

  private func remove(id: UUID) {
    continuations.removeValue(forKey: id)
  }
}
