//
//  PostAuthorRowView.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//
//  Pencil node: z24GR (d_author)
//

import SwiftUI

struct PostAuthorRowView: View {
  let creator: UserInfoResponseDTO
  let createdAtRelative: String
  let isOwn: Bool
  let authorAction: () -> Void
  let editAction: () -> Void
  let deleteAction: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      Button(action: authorAction) {
        avatar
      }
      .buttonStyle(.plain)
      .accessibilityLabel("작성자 게시글 보기")

      VStack(alignment: .leading, spacing: 2) {
        Text(creator.nick.isEmpty ? "익명" : creator.nick)
          .font(AppTheme.pretendard(size: 13, weight: .bold))
          .foregroundStyle(AppTheme.gray30)
        if !createdAtRelative.isEmpty {
          Text(createdAtRelative)
            .font(AppTheme.pretendard(size: 11, weight: .medium))
            .foregroundStyle(AppTheme.gray60)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      if isOwn {
        Button(action: editAction) {
          Image(systemName: "pencil")
            .font(AppTheme.symbol(size: 18, weight: .regular))
            .foregroundStyle(AppTheme.gray60)
            .frame(width: 32, height: 32)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("게시글 수정")
        .accessibilityIdentifier("post_detail_edit_button")

        Button(action: deleteAction) {
          Image(systemName: "trash")
            .font(AppTheme.symbol(size: 18, weight: .regular))
            .foregroundStyle(AppTheme.gray60)
            .frame(width: 32, height: 32)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("게시글 삭제")
        .accessibilityIdentifier("post_detail_delete_button")
      }
    }
    .frame(height: 44)
  }

  private var avatar: some View {
    ChatImageView(
      path: creator.profileImage,
      baseURL: nil,
      shape: .circle
    )
    .frame(width: 38, height: 38)
    .overlay {
      Circle().stroke(AppTheme.brightTurquoise, lineWidth: 2)
    }
  }
}
