//
//  ProfileActionRow.swift
//  ToneAtelier
//
//  Created by Codex on 5/1/26.
//

import SwiftUI

struct ProfileActionRow: View {
  let editAction: () -> Void
  let storeAction: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      Button(action: editAction) {
        actionLabel(
          icon: Image(systemName: AppAsset.Profile.editProfile),
          title: "프로필 편집",
          foreground: AppTheme.gray30
        )
        .background(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(AppTheme.brightTurquoise)
        )
      }
      .buttonStyle(.plain)

      Button(action: storeAction) {
        actionLabel(
          icon: Image(AppAsset.Profile.creatorStore).renderingMode(.template),
          title: "작품 보기",
          foreground: AppTheme.gray60
        )
        .background(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(AppTheme.blackTurquoise)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(AppTheme.deepTurquoise, lineWidth: 1)
        )
      }
      .buttonStyle(.plain)
    }
    .frame(height: 44)
  }

  private func actionLabel(
    icon: Image,
    title: String,
    foreground: Color
  ) -> some View {
    HStack(spacing: 6) {
      icon
        .resizable()
        .scaledToFit()
        .frame(width: 16, height: 16)

      Text(title)
        .font(AppTheme.pretendard(size: 14, weight: .bold))
    }
    .foregroundStyle(foreground)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(.horizontal, 14)
  }
}

#Preview {
  ProfileActionRow(editAction: {}, storeAction: {})
    .padding(20)
    .background(AppTheme.background)
    .preferredColorScheme(.dark)
}
