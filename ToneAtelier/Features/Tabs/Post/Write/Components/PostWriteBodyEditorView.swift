//
//  PostWriteBodyEditorView.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//
//  Pencil node: oALoY (e_bodyBox)
//

import SwiftUI

struct PostWriteBodyEditorView: View {
  @Binding var title: String
  @Binding var content: String

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("제목 / 본문 *")
        .pretendard(.captionMeta)
        .foregroundStyle(AppTheme.gray75)

      TextField("제목을 입력해주세요", text: $title)
        .pretendard(.body2)
        .foregroundStyle(AppTheme.gray30)
        .tint(AppTheme.gray30)
        .padding(.vertical, 6)
        .accessibilityIdentifier("post_write_title_field")

      Rectangle()
        .fill(AppTheme.deepTurquoise)
        .frame(height: 0.5)

      TextField(
        "본문을 입력하고 사진이나 영상을 첨부해 게시글을 작성해 보세요.",
        text: $content,
        axis: .vertical
      )
      .pretendard(.body3)
      .foregroundStyle(AppTheme.gray60)
      .tint(AppTheme.gray30)
      .lineLimit(5...10)
      .frame(minHeight: 110, alignment: .topLeading)
      .accessibilityIdentifier("post_write_body_field")
    }
    .padding(12)
    .background(AppTheme.blackTurquoise)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
  }
}
