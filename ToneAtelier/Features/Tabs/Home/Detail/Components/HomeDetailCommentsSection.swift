//
//  HomeDetailCommentsSection.swift
//  ToneAtelier
//
//  Pencil node: uDBGg (cnobaComments)
//

import SwiftUI

struct HomeDetailCommentsSection: View {
  let comments: [FilterCommentResponseDTO]
  let currentUserID: String?
  let replyTargetCommentID: String?
  let editingCommentID: String?
  let onReplyTrigger: (String, String) -> Void
  let onEditTrigger: (String, String) -> Void
  let onDeleteTrigger: (String) -> Void

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
        CommentRowView(
          comment: comment.asCommentDisplay,
          isOwn: currentUserID != nil && currentUserID == comment.creator.userID,
          isReplyTarget: replyTargetCommentID == comment.commentID,
          isEditing: editingCommentID == comment.commentID,
          editingCommentID: editingCommentID,
          replyOwnerEvaluator: { reply in
            currentUserID != nil && currentUserID == reply.creatorUserID
          },
          onReplyTapped: {
            onReplyTrigger(comment.commentID, comment.creator.nick)
          },
          onEditTapped: {
            onEditTrigger(comment.commentID, comment.content)
          },
          onDeleteTapped: {
            onDeleteTrigger(comment.commentID)
          },
          onReplyEditTapped: { reply in
            onEditTrigger(reply.commentID, reply.content)
          },
          onReplyDeleteTapped: { reply in
            onDeleteTrigger(reply.commentID)
          }
        )
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(AppTheme.blackTurquoise)
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
  }
}
