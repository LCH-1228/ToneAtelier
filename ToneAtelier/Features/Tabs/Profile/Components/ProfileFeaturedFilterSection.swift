//
//  ProfileFeaturedFilterSection.swift
//  ToneAtelier
//
//  Created by Codex on 5/1/26.
//

import SwiftUI

struct ProfileFeaturedFilterSection: View {
  let filter: FeaturedFilter?
  let action: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("대표 필터")
        .font(AppTheme.pretendard(size: 16, weight: .bold))
        .foregroundStyle(AppTheme.gray60)

      if let filter {
        FeaturedFilterCard(filter: filter, action: action)
      } else {
        FeaturedFilterPlaceholderCard()
      }
    }
  }
}

#Preview {
  VStack(spacing: 20) {
    ProfileFeaturedFilterSection(filter: .placeholder, action: {})
    ProfileFeaturedFilterSection(filter: nil, action: {})
  }
  .padding(20)
  .background(AppTheme.background)
  .preferredColorScheme(.dark)
}
