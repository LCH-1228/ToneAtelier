//
//  ProfileLikedFilterSection.swift
//  ToneAtelier
//
//  Created by Codex on 5/1/26.
//

import SwiftUI

struct ProfileLikedFilterSection: View {
  let filters: [LikedFilter]
  let filterAction: (LikedFilter.ID) -> Void
  let viewAllAction: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 0) {
        Text("좋아하는 필터")
          .font(AppTheme.pretendard(size: 16, weight: .bold))
          .foregroundStyle(AppTheme.gray60)

        Spacer(minLength: 0)

        Button(action: viewAllAction) {
          Text("더보기")
            .font(AppTheme.pretendard(size: 14, weight: .bold))
            .foregroundStyle(AppTheme.brightTurquoise)
            .padding(.vertical, 8)
            .padding(.leading, 12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("좋아하는 필터 더보기")
      }

      HStack(spacing: 10) {
        ForEach(filters) { filter in
          LikedFilterCard(filter: filter) {
            filterAction(filter.id)
          }
        }
      }
      .frame(height: 132)
    }
  }
}

#Preview {
  ProfileLikedFilterSection(
    filters: LikedFilter.placeholders,
    filterAction: { _ in },
    viewAllAction: {}
  )
  .padding(20)
  .background(AppTheme.background)
  .preferredColorScheme(.dark)
}
