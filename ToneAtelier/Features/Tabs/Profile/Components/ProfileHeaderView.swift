//
//  ProfileHeaderView.swift
//  ToneAtelier
//
//  Created by Codex on 5/1/26.
//

import SwiftUI

struct ProfileHeaderView: View {
  let action: () -> Void

  var body: some View {
    HStack(spacing: 0) {
      Spacer()
      Button(action: action) {
        Image(AppAsset.Profile.settings)
          .renderingMode(.template)
          .resizable()
          .scaledToFit()
          .foregroundStyle(AppTheme.gray60)
          .frame(width: 22, height: 22)
          .frame(width: 48, height: 48)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("설정")
    }
    .overlay {
      Text("PROFILE")
        .font(AppTheme.mulgyeol(size: 20))
        .foregroundStyle(AppTheme.gray60)
        .accessibilityAddTraits(.isHeader)
    }
    .frame(height: 56)
    .padding(.horizontal, 20)
  }
}

#Preview {
  ProfileHeaderView(action: {})
    .background(AppTheme.background)
    .preferredColorScheme(.dark)
}
