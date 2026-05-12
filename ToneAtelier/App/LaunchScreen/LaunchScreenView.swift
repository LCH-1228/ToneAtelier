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
          Text("Atelier")
        }
        .font(.custom("Pretendard-Bold", size: 74))
        .foregroundStyle(.white)

        Text("Tone Atelier")
          .font(.custom("Pretendard-Bold", size: 14))
          .foregroundStyle(AppTheme.gray60)

        RoundedRectangle(cornerRadius: 2, style: .continuous)
          .fill(AppTheme.gray60)
          .frame(width: 100, height: 4)
      }
    }
    .preferredColorScheme(.dark)
  }
}

#Preview {
  LaunchScreenView(
    store: Store(initialState: LaunchScreenFeature.State()) {
      LaunchScreenFeature()
    }
  )
}
