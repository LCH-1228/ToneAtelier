//
//  AppToast.swift
//  ToneAtelier
//

import SwiftUI

/// 앱 전역 toast 표시 단일 채널. AppRootView 가 overlay 로 binding 한다.
@MainActor
@Observable
final class ToastCenter {
  static let shared = ToastCenter()

  private(set) var currentMessage: String?

  private var hideTask: Task<Void, Never>?

  private init() {}

  func show(_ message: String, duration: Double = 2.5) {
    hideTask?.cancel()
    currentMessage = message
    hideTask = Task { [weak self] in
      try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
      guard !Task.isCancelled else { return }
      self?.currentMessage = nil
    }
  }
}

struct ToastOverlay: View {
  @Bindable var center: ToastCenter

  var body: some View {
    VStack {
      Spacer()
      if let message = center.currentMessage {
        Text(message)
          .pretendard(.body3)
          .foregroundStyle(AppTheme.gray30)
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
          .background(AppTheme.blackTurquoise.opacity(0.95), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
          .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
              .strokeBorder(AppTheme.deepTurquoise, lineWidth: 1)
          )
          .padding(.bottom, 80)
          .padding(.horizontal, 24)
          .transition(.move(edge: .bottom).combined(with: .opacity))
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .allowsHitTesting(false)
    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: center.currentMessage)
  }
}
