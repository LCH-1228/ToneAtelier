//
//  PostActionsBarView.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//
//  Pencil node: gBGk5 (d_actions)
//

import SwiftUI

struct PostActionsBarView: View {
  let isLike: Bool
  let likeCount: Double
  let commentCount: Int
  let likeAction: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      Button(action: likeAction) {
        HStack(spacing: 6) {
          Image(systemName: isLike ? "heart.fill" : "heart")
            .font(AppTheme.symbol(size: 14, weight: .regular))
            .foregroundStyle(isLike ? AppTheme.brightTurquoise : AppTheme.gray60)
          Text(formattedCount(likeCount))
            .pretendard(.captionBold)
            .foregroundStyle(AppTheme.gray30)
        }
        .frame(height: 32)
        .padding(.horizontal, 12)
        .background(AppTheme.deepTurquoise)
        .clipShape(Capsule())
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(isLike ? "좋아요 취소" : "좋아요")
      .accessibilityIdentifier("post_detail_like_button")

      HStack(spacing: 6) {
        Image(systemName: "bubble.right")
          .font(AppTheme.symbol(size: 14, weight: .regular))
          .foregroundStyle(AppTheme.gray60)
        Text("\(commentCount)")
          .pretendard(.captionBold)
          .foregroundStyle(AppTheme.gray30)
      }
      .frame(height: 32)
      .padding(.horizontal, 12)
      .background(AppTheme.blackTurquoise)
      .clipShape(Capsule())

      Spacer(minLength: 0)
    }
  }

  private func formattedCount(_ value: Double) -> String {
    let intValue = Int(value)
    if intValue >= 1000 {
      let truncated = Double(intValue) / 1000
      return String(format: "%.1fK", truncated)
    }
    return "\(intValue)"
  }
}
