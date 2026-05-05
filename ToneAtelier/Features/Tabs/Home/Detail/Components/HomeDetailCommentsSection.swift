//
//  HomeDetailCommentsSection.swift
//  ToneAtelier
//
//  Pencil node: uDBGg (cnobaComments)
//

import SwiftUI

struct HomeDetailCommentsSection: View {
  let comments: [FilterCommentResponseDTO]
  let replyTargetCommentID: String?
  let onReplyTrigger: (String, String) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("댓글")
        .pretendard(.body3Bold)
        .foregroundStyle(AppTheme.gray30)

      if comments.isEmpty {
        Text("첫 댓글을 남겨보세요.")
          .pretendard(.caption1)
          .foregroundStyle(AppTheme.gray75)
          .frame(maxWidth: .infinity, alignment: .center)
          .padding(.vertical, 12)
      }

      ForEach(comments, id: \.commentID) { comment in
        // owner 액션(편집/삭제) 은 3단계에서 채움.
        CommentRowView(
          comment: comment.asCommentDisplay,
          isOwn: false,
          isReplyTarget: replyTargetCommentID == comment.commentID,
          isEditing: false,
          editingCommentID: nil,
          replyOwnerEvaluator: { _ in false },
          onReplyTapped: {
            onReplyTrigger(comment.commentID, comment.creator.nick)
          },
          onEditTapped: {},
          onDeleteTapped: {},
          onReplyEditTapped: { _ in },
          onReplyDeleteTapped: { _ in }
        )
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(AppTheme.blackTurquoise)
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
  }
}
