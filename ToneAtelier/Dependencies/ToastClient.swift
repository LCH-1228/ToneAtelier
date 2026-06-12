//
//  ToastClient.swift
//  ToneAtelier
//

import ComposableArchitecture
import Foundation

struct ToastClient: Sendable {
  var show: @Sendable (_ message: String) async -> Void
}

extension ToastClient: DependencyKey {
  static let liveValue = ToastClient(
    show: { message in
      await MainActor.run {
        ToastCenter.shared.show(message)
      }
    }
  )

  static let testValue = ToastClient(
    show: { _ in }
  )
}

extension DependencyValues {
  var toastClient: ToastClient {
    get { self[ToastClient.self] }
    set { self[ToastClient.self] = newValue }
  }
}
