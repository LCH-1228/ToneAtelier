//
//  ProfileSummaryCard.swift
//  ToneAtelier
//
//  Created by Codex on 5/1/26.
//

import SwiftUI

struct ProfileSummaryCard: View {
  let summary: ProfileSummary

  var body: some View {
    VStack(spacing: 8) {
      ProfileAvatarView(urlString: summary.avatarURL)

      Text(summary.name)
        .font(AppTheme.pretendard(size: 12, weight: .bold))
        .foregroundStyle(AppTheme.gray75)

      Text(summary.nickname)
        .font(AppTheme.mulgyeol(size: 24))
        .foregroundStyle(AppTheme.gray30)

      Text(summary.bio)
        .font(AppTheme.pretendard(size: 11, weight: .medium))
        .foregroundStyle(AppTheme.gray60)
        .multilineTextAlignment(.center)
        .lineSpacing(5)
        .frame(maxWidth: .infinity)

      ProfileStatsRow(stats: summary.stats)
        .padding(.top, 4)
    }
    .padding(EdgeInsets(top: 14, leading: 16, bottom: 16, trailing: 16))
    .background(
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .fill(AppTheme.blackTurquoise)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .stroke(AppTheme.deepTurquoise, lineWidth: 1)
    )
  }
}

private struct ProfileAvatarView: View {
  let urlString: String?

  var body: some View {
    ZStack {
      Circle()
        .fill(AppTheme.deepTurquoise)

      if let urlString, !urlString.isEmpty {
        HomeRemoteImageView(urlString: urlString)
          .scaledToFill()
          .clipShape(Circle())
      } else {
        Image(AppAsset.Profile.avatar)
          .renderingMode(.template)
          .resizable()
          .scaledToFit()
          .padding(18)
          .foregroundStyle(AppTheme.gray60)
      }
    }
    .frame(width: 72, height: 72)
    .overlay {
      Circle()
        .stroke(AppTheme.brightTurquoise, lineWidth: 3)
    }
  }
}

#Preview {
  ProfileSummaryCard(summary: .placeholder)
    .padding(20)
    .background(AppTheme.background)
    .preferredColorScheme(.dark)
}
