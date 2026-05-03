//
//  PostSearchResultRowView.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//
//  Pencil node: RmFAs / Y6tObe (s_result)
//

import SwiftUI

struct PostSearchResultRowView: View {
  let post: PostSummaryResponseDTO
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 12) {
        ChatImageView(
          path: post.files.first,
          baseURL: nil,
          shape: .roundedRect(cornerRadius: 10)
        )
        .frame(width: 88, height: 88)

        VStack(alignment: .leading, spacing: 6) {
          Text(post.title.isEmpty ? "제목 없음" : post.title)
            .font(AppTheme.pretendard(size: 14, weight: .bold))
            .foregroundStyle(AppTheme.gray30)
            .lineLimit(1)
            .truncationMode(.tail)

          Text(metaLine)
            .font(AppTheme.pretendard(size: 11, weight: .bold))
            .foregroundStyle(AppTheme.gray75)
            .lineLimit(1)
            .truncationMode(.tail)

          Text(post.content)
            .font(AppTheme.pretendard(size: 11, weight: .medium))
            .foregroundStyle(AppTheme.gray60)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(12)
      .background(AppTheme.blackTurquoise)
      .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(post.title) 게시글 보기")
  }

  private var metaLine: String {
    let nick = post.creator.nick.isEmpty ? "익명" : post.creator.nick
    let attachments = "사진 \(post.files.count)"
    return "\(nick) · \(attachments)"
  }
}
