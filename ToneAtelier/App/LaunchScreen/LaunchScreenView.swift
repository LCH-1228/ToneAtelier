//
//  LaunchScreenView.swift
//  ToneAtelier
//
//  Created by Codex on 5/12/26.
//

import ComposableArchitecture
import SwiftUI

struct LaunchScreenView: View {
  let store: StoreOf<LaunchScreenFeature>

  @State private var toneOpacity: Double = 0
  @State private var toneOffset: CGFloat = 8
  @State private var atelierOpacity: Double = 0
  @State private var atelierOffset: CGFloat = 8
  @State private var subcopyOpacity: Double = 0
  @State private var barWidth: CGFloat = 0

  var body: some View {
    ZStack {
      HStack(spacing: 0) {
        AppTheme.blackTurquoise
        AppTheme.deepTurquoise
      }
      .ignoresSafeArea()

      VStack(spacing: 12) {
        VStack(spacing: 0) {
          Text("Tone")
            .opacity(toneOpacity)
            .offset(y: toneOffset)
          Text("Atelier")
            .opacity(atelierOpacity)
            .offset(y: atelierOffset)
        }
        .font(.custom("Pretendard-Bold", size: 74))
        .foregroundStyle(.white)

        Text("Tone Atelier")
          .font(.custom("Pretendard-Bold", size: 14))
          .foregroundStyle(AppTheme.gray60)
          .opacity(subcopyOpacity)

        RoundedRectangle(cornerRadius: 2, style: .continuous)
          .fill(AppTheme.gray60)
          .frame(width: barWidth, height: 4)
      }
    }
    .preferredColorScheme(.dark)
    .task {
      store.send(.task)
      runEntranceAnimation()
    }
  }

  private func runEntranceAnimation() {
    withAnimation(.easeOut(duration: 0.5)) {
      toneOpacity = 1
      toneOffset = 0
    }
    withAnimation(.easeOut(duration: 0.5).delay(0.15)) {
      atelierOpacity = 1
      atelierOffset = 0
    }
    withAnimation(.easeOut(duration: 0.4).delay(0.4)) {
      subcopyOpacity = 1
    }
    withAnimation(.easeInOut(duration: 0.7).delay(0.6)) {
      barWidth = 100
    }
  }
}

#Preview {
  LaunchScreenView(
    store: Store(initialState: LaunchScreenFeature.State()) {
      LaunchScreenFeature()
    }
  )
}
