//
//  UserPostsUnknownStateView.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//
//  Pencil node: r4DND (Unknown User State View)
//

import SwiftUI

struct UserPostsUnknownStateView: View {
  let onRetryTap: () -> Void
  let onBackToListTap: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      Spacer(minLength: 24)

      VStack(spacing: 18) {
        avatar
        Text("알 수 없는 계정이에요")
          .font(AppTheme.mulgyeol(size: 22))
          .foregroundStyle(AppTheme.gray30)
        Text("삭제되었거나 접근할 수 없는 사용자라 작성한 게시글을 불러올 수 없어요.")
          .font(AppTheme.pretendard(size: 13, weight: .semibold))
          .foregroundStyle(AppTheme.gray60)
          .lineSpacing(2)
          .multilineTextAlignment(.center)
          .frame(maxWidth: 282)
      }

      Spacer(minLength: 16)

      infoCard

      Spacer(minLength: 32)

      VStack(spacing: 12) {
        Button(action: onRetryTap) {
          Text("다시 불러오기")
            .font(AppTheme.pretendard(size: 14, weight: .bold))
            .foregroundStyle(AppTheme.gray30)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(AppTheme.brightTurquoise)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)

        Button(action: onBackToListTap) {
          Text("게시글 목록으로 이동")
            .font(AppTheme.pretendard(size: 14, weight: .bold))
            .foregroundStyle(AppTheme.gray30)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(AppTheme.blackTurquoise)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
      }

      Spacer(minLength: 8)
    }
    .padding(.horizontal, 20)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var avatar: some View {
    ZStack {
      Circle().fill(AppTheme.blackTurquoise)
      Image(systemName: "person.crop.circle.badge.xmark")
        .font(AppTheme.symbol(size: 46, weight: .regular))
        .foregroundStyle(AppTheme.brightTurquoise)
    }
    .frame(width: 104, height: 104)
    .overlay {
      Circle().stroke(AppTheme.deepTurquoise, lineWidth: 1)
    }
  }

  private var infoCard: some View {
    HStack(spacing: 10) {
      Image(systemName: "shield.lefthalf.filled.badge.checkmark")
        .font(AppTheme.symbol(size: 22, weight: .regular))
        .foregroundStyle(AppTheme.gray60)
      Text("계정 정보가 복구되면 작성 게시글을 다시 확인할 수 있어요.")
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
