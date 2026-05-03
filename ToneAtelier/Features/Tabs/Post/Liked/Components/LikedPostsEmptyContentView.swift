//
//  LikedPostsEmptyContentView.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//
//  Pencil node: Ycgaz (likedEmptyContent) + YAgg1 (likedEmptyHint) + u4isY (likedEmptyExploreButton)
//

import SwiftUI

struct LikedPostsEmptyContentView: View {
  let onExploreTap: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      Spacer(minLength: 32)

      VStack(spacing: 18) {
        illustration
        Text("아직 좋아요한 게시글이 없어요")
          .font(AppTheme.mulgyeol(size: 22))
          .foregroundStyle(AppTheme.gray30)
        Text("마음에 드는 필터 후기나 사진 게시글에 좋아요를 누르면 여기에 저장됩니다.")
          .font(AppTheme.pretendard(size: 13, weight: .semibold))
          .foregroundStyle(AppTheme.gray60)
          .lineSpacing(2)
          .multilineTextAlignment(.center)
          .frame(maxWidth: 284)
      }

      Spacer(minLength: 24)

      hintCard

      Spacer(minLength: 24)

      Button(action: onExploreTap) {
        Text("게시글 둘러보기")
          .font(AppTheme.pretendard(size: 14, weight: .bold))
          .foregroundStyle(AppTheme.gray30)
          .frame(maxWidth: .infinity)
          .frame(height: 48)
          .background(AppTheme.brightTurquoise)
          .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
      }
      .buttonStyle(.plain)

      Spacer(minLength: 16)
    }
    .padding(.horizontal, 20)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var illustration: some View {
    ZStack {
      Circle().fill(AppTheme.blackTurquoise)
      Image(systemName: "heart.slash")
        .font(AppTheme.symbol(size: 40, weight: .regular))
        .foregroundStyle(AppTheme.brightTurquoise)
    }
    .frame(width: 104, height: 104)
    .overlay {
      Circle().stroke(AppTheme.deepTurquoise, lineWidth: 1)
    }
  }

  private var hintCard: some View {
    HStack(spacing: 10) {
      Image(systemName: "sparkles")
        .font(AppTheme.symbol(size: 22, weight: .regular))
        .foregroundStyle(AppTheme.gray60)
      Text("게시글 목록에서 좋아요를 누르면 카테고리별로 다시 찾아볼 수 있어요.")
        .font(AppTheme.pretendard(size: 12, weight: .bold))
        .foregroundStyle(AppTheme.gray60)
        .lineSpacing(2)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(AppTheme.blackTurquoise)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }
}
