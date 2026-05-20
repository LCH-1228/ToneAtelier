//
//  HomeVideoTeaserCard.swift
//  ToneAtelier
//
//  Created by Claude on 5/7/26.
//

import SwiftUI

struct HomeVideoTeaserCard: View {
  let video: VideoResponseDTO
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      ZStack(alignment: .bottomLeading) {
        CachedImageView(urlString: video.thumbnailURL)
          .frame(maxWidth: .infinity)
          .frame(height: 140)
          .clipped()

        LinearGradient(
          colors: [Color.black.opacity(0.0), Color.black.opacity(0.75)],
          startPoint: .top,
          endPoint: .bottom
        )

        VStack(alignment: .leading, spacing: 6) {
          HStack(spacing: 6) {
            Image(systemName: "play.rectangle.fill")
              .font(AppTheme.symbol(size: 12, weight: .semibold))
              .foregroundStyle(AppTheme.brightTurquoise)
            Text("PHOTOGRAPHER'S NOTE")
              .pretendard(.caption2Bold)
              .foregroundStyle(AppTheme.brightTurquoise)
              .tracking(1.0)
          }
          Text("사진을 다르게 담는 법")
            .pretendard(.body1)
            .foregroundStyle(.white)
            .lineLimit(1)
          Text("작가들의 시선, 영상 강좌로 만나보세요")
            .pretendard(.caption1)
            .foregroundStyle(.white.opacity(0.85))
            .lineLimit(1)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
      }
      .frame(height: 140)
      .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("영상 강좌 — 사진을 다르게 담는 법")
  }
}
