//
//  MakeAutoTuneButton.swift
//  ToneAtelier
//
//  Created by Codex on 5/6/26.
//

import ComposableArchitecture
import SwiftUI

struct MakeAutoTuneButton: View {
  let store: StoreOf<MakeAutoTuneFeature>

  var body: some View {
    Button {
      store.send(.recommendButtonTapped)
    } label: {
      HStack(spacing: 6) {
        if store.isRecommending {
          ProgressView()
            .controlSize(.small)
            .tint(AppTheme.gray30)
        } else {
          Image(systemName: "wand.and.stars")
            .font(AppTheme.symbol(size: 14, weight: .semibold))
        }

        Text(store.isRecommending ? "추천 중" : "스마트 추천")
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
    .disabled(store.isRecommending)
    .accessibilityLabel("스마트 필터 추천")
  }
}

#Preview {
  MakeAutoTuneButton(
    store: Store(initialState: MakeAutoTuneFeature.State()) {
      MakeAutoTuneFeature()
    }
  )
  .padding()
  .background(Color.black)
}
