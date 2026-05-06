//
//  MakeAutoTuneButton.swift
//  ToneAtelier
//
//  Created by Codex on 5/6/26.
//

import SwiftUI

struct MakeAutoTuneButton: View {
  let isRecommending: Bool
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 6) {
        if isRecommending {
          ProgressView()
            .controlSize(.small)
            .tint(AppTheme.gray30)
        } else {
          Image(systemName: "wand.and.stars")
            .font(AppTheme.symbol(size: 14, weight: .semibold))
        }

        Text(isRecommending ? "추천 중" : "스마트 추천")
          .pretendard(.body2)
      }
      .foregroundStyle(AppTheme.gray30)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(AppTheme.blackTurquoise.opacity(0.85), in: .rect(cornerRadius: 16))
      .overlay {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(AppTheme.deepTurquoise.opacity(0.6), lineWidth: 1)
      }
    }
    .buttonStyle(.plain)
    .disabled(isRecommending)
    .accessibilityLabel("스마트 필터 추천")
  }
}

#Preview {
  MakeAutoTuneButton(isRecommending: false, onTap: {})
    .padding()
    .background(Color.black)
}
