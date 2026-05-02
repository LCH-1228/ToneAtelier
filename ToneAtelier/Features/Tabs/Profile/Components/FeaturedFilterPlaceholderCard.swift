//
//  FeaturedFilterPlaceholderCard.swift
//  ToneAtelier
//
//  Created by Codex on 5/1/26.
//

import SwiftUI

struct FeaturedFilterPlaceholderCard: View {
  var body: some View {
    RoundedRectangle(cornerRadius: 16, style: .continuous)
      .fill(AppTheme.blackTurquoise)
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(AppTheme.deepTurquoise, lineWidth: 1)
      )
      .overlay(
        Text("아직 등록된 대표 필터가 없어요.")
          .font(AppTheme.pretendard(size: 12, weight: .medium))
          .foregroundStyle(AppTheme.gray75)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 24)
      )
      .frame(height: 96)
  }
}

#Preview {
  FeaturedFilterPlaceholderCard()
    .padding(20)
    .background(AppTheme.background)
    .preferredColorScheme(.dark)
}
