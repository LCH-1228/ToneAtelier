//
//  LikedPostsSummaryView.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//
//  Pencil node: RdbJ5 (p_summary) / Dwy00 (likedEmptySummary)
//

import SwiftUI

struct LikedPostsSummaryView: View {
  let title: String
  let subtitle: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(AppTheme.mulgyeol(size: 18))
        .foregroundStyle(AppTheme.gray30)

      Text(subtitle)
        .font(AppTheme.pretendard(size: 11, weight: .bold))
        .foregroundStyle(AppTheme.gray75)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(AppTheme.blackTurquoise)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }
}
