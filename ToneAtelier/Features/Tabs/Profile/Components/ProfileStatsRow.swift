//
//  ProfileStatsRow.swift
//  ToneAtelier
//
//  Created by Codex on 5/1/26.
//

import SwiftUI

struct ProfileStatsRow: View {
  let stats: [ProfileStat]

  var body: some View {
    HStack(spacing: 8) {
      ForEach(stats) { stat in
        VStack(spacing: 4) {
          Text(stat.value)
            .font(AppTheme.pretendard(size: 16, weight: .bold))
            .foregroundStyle(AppTheme.gray30)

          Text(stat.label)
            .font(AppTheme.pretendard(size: 10, weight: .semibold))
            .foregroundStyle(AppTheme.gray75)
        }
        .frame(maxWidth: .infinity)
      }
    }
  }
}

#Preview {
  ProfileStatsRow(stats: ProfileSummary.placeholder.stats)
    .padding()
    .background(AppTheme.blackTurquoise)
    .preferredColorScheme(.dark)
}
