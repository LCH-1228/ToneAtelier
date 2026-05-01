//
//  FeaturedFilterCard.swift
//  ToneAtelier
//
//  Created by Codex on 5/1/26.
//

import SwiftUI

struct FeaturedFilterCard: View {
  let filter: FeaturedFilter
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(AppTheme.deepTurquoise)
          .frame(width: 76, height: 76)

        VStack(alignment: .leading, spacing: 7) {
          Text(filter.name)
            .font(AppTheme.mulgyeol(size: 22))
            .foregroundStyle(AppTheme.gray30)

          Text(filter.meta)
            .font(AppTheme.pretendard(size: 11, weight: .semibold))
            .foregroundStyle(AppTheme.gray75)

          Text(filter.description)
            .font(AppTheme.pretendard(size: 11, weight: .medium))
            .foregroundStyle(AppTheme.gray60)
            .lineSpacing(4)
            .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(10)
      .frame(height: 96)
      .background(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(AppTheme.blackTurquoise)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(AppTheme.deepTurquoise, lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
  }
}

#Preview {
  FeaturedFilterCard(filter: .placeholder, action: {})
    .padding(20)
    .background(AppTheme.background)
    .preferredColorScheme(.dark)
}
