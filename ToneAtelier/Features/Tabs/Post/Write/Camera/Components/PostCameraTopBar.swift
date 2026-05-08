//
//  PostCameraTopBar.swift
//  ToneAtelier
//
//  Pencil node: pJjZX 상단 close + flash + flip — 디자인의 "모드 pill" 은 하단 mode strip 으로 이전.
//

import SwiftUI

struct PostCameraTopBar: View {
  let flashMode: PostCameraFlashMode
  let onClose: () -> Void
  let onFlashTap: () -> Void
  let onFlipTap: () -> Void

  var body: some View {
    HStack(spacing: 0) {
      glassIconButton(
        systemName: "xmark",
        accessibilityLabel: "닫기",
        action: onClose
      )

      Spacer(minLength: 0)

      HStack(spacing: 6) {
        glassIconButton(
          systemName: flashMode.symbolName,
          accessibilityLabel: "플래시 \(flashMode.accessibilityLabel)",
          tint: flashMode == .off ? AppTheme.gray30 : AppTheme.brightTurquoise,
          action: onFlashTap
        )
        glassIconButton(
          systemName: "arrow.triangle.2.circlepath",
          accessibilityLabel: "카메라 전환",
          action: onFlipTap
        )
      }
    }
    .padding(.horizontal, 18)
    .frame(height: 36)
  }

  private func glassIconButton(
    systemName: String,
    accessibilityLabel: String,
    tint: Color = AppTheme.gray30,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(AppTheme.symbol(size: 18, weight: .regular))
        .foregroundStyle(tint)
        .frame(width: 36, height: 36)
        .background(PostCameraColors.glass)
        .clipShape(Circle())
        .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(accessibilityLabel)
  }
}

private extension PostCameraFlashMode {
  var symbolName: String {
    switch self {
    case .off: return "bolt.slash"
    case .on: return "bolt.fill"
    case .auto: return "bolt.badge.a"
    }
  }

  var accessibilityLabel: String {
    switch self {
    case .off: return "끔"
    case .on: return "켬"
    case .auto: return "자동"
    }
  }
}

/// pJjZX/VlQiR 디자인 토큰 — 글래스 배경 #0F121388.
enum PostCameraColors {
  static let glass = Color(red: 15.0 / 255, green: 18.0 / 255, blue: 19.0 / 255).opacity(0.55)
  static let glassDark = Color(red: 15.0 / 255, green: 18.0 / 255, blue: 19.0 / 255).opacity(0.67)
  static let warmTint = Color(red: 229.0 / 255, green: 164.0 / 255, blue: 99.0 / 255).opacity(0.13)
  static let warmSwatch = Color(red: 229.0 / 255, green: 164.0 / 255, blue: 99.0 / 255)
  static let dividerLine = Color(red: 234.0 / 255, green: 234.0 / 255, blue: 234.0 / 255).opacity(0.4)
}
