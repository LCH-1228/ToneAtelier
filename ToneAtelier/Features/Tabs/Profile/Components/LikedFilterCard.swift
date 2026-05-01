//
//  LikedFilterCard.swift
//  ToneAtelier
//
//  Created by Codex on 5/1/26.
//

import SwiftUI

struct LikedFilterCard: View {
  let filter: LikedFilter
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 8) {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(AppTheme.deepTurquoise)
          .frame(maxWidth: .infinity)
          .frame(height: 64)

        Text(filter.title)
          .font(AppTheme.pretendard(size: 13, weight: .bold))
          .foregroundStyle(AppTheme.gray30)

        Text("\(filter.likeCount)개")
          .font(AppTheme.pretendard(size: 11, weight: .semibold))
          .foregroundStyle(AppTheme.gray75)
      }
      .padding(9)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
  HStack(spacing: 10) {
    ForEach(LikedFilter.placeholders) { filter in
      LikedFilterCard(filter: filter, action: {})
    }
  }
  .frame(height: 132)
  .padding(20)
  .background(AppTheme.background)
  .preferredColorScheme(.dark)
}
