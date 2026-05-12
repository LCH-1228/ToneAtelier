//
//  CommentRowView.swift
//  ToneAtelier
//

import SwiftUI

struct CommentRowView: View {
  let comment: CommentDisplayItem
  let isOwn: Bool
  let isReplyTarget: Bool
  let isEditing: Bool
  let editingCommentID: String?
  let replyOwnerEvaluator: (CommentDisplayItem) -> Bool
  let onReplyTapped: () -> Void
  let onEditTapped: () -> Void
  let onDeleteTapped: () -> Void
  let onReplyEditTapped: (CommentDisplayItem) -> Void
  let onReplyDeleteTapped: (CommentDisplayItem) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      mainCommentRow
      if !comment.replies.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          ForEach(comment.replies) { reply in
            replyRow(reply)
          }
        }
        .padding(.leading, 32)
      }
    }
  }

  private var mainCommentRow: some View {
    HStack(alignment: .top, spacing: 10) {
      ChatImageView(
        path: comment.profileImageURL,
        baseURL: nil,
        shape: .circle
      )
      .frame(width: 30, height: 30)
      .overlay {
        Circle().stroke(AppTheme.brightTurquoise.opacity(0.6), lineWidth: 1)
      }

      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 6) {
          Text(comment.nick.isEmpty ? "익명" : comment.nick)
            .pretendard(.captionBold)
            .foregroundStyle(AppTheme.gray30)
            .lineLimit(1)
            .truncationMode(.tail)
          Text(comment.createdAt.relativeKoreanShort)
            .pretendard(.caption2Bold)
            .foregroundStyle(AppTheme.gray75)

          Spacer(minLength: 0)

          Button(action: onReplyTapped) {
            HStack(spacing: 4) {
              Image(systemName: "arrow.turn.down.right")
                .font(AppTheme.symbol(size: 10, weight: .regular))
              Text("답글")
                .pretendard(.caption2Bold)
            }
            .foregroundStyle(isReplyTarget ? AppTheme.brightTurquoise : AppTheme.gray60)
            .padding(.horizontal, 8)
            .frame(height: 20)
            .background(AppTheme.deepTurquoise)
            .clipShape(Capsule())
            .contentShape(.rect)
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("comment_reply_button")

          if isOwn {
            Button(action: onEditTapped) {
              Image(systemName: "pencil")
                .font(AppTheme.symbol(size: 12, weight: .regular))
                .foregroundStyle(isEditing ? AppTheme.brightTurquoise : AppTheme.gray60)
                .frame(width: 22, height: 20)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("댓글 수정")

            Button(action: onDeleteTapped) {
              Image(systemName: "trash")
                .font(AppTheme.symbol(size: 12, weight: .regular))
                .foregroundStyle(AppTheme.gray60)
                .frame(width: 22, height: 20)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("댓글 삭제")
          }
        }

        Text(comment.content)
          .pretendard(.captionMeta)
          .foregroundStyle(AppTheme.gray60)
          .lineLimit(8)
          .multilineTextAlignment(.leading)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private func replyRow(_ reply: CommentDisplayItem) -> some View {
    let isReplyOwn = replyOwnerEvaluator(reply)
    let isReplyEditing = editingCommentID == reply.commentID

    return HStack(alignment: .top, spacing: 6) {
      Image(systemName: "arrow.turn.down.right")
        .font(AppTheme.symbol(size: 10, weight: .regular))
        .foregroundStyle(AppTheme.gray75)
        .frame(width: 12, height: 12)

      ChatImageView(
        path: reply.profileImageURL,
        baseURL: nil,
        shape: .circle
      )
      .frame(width: 24, height: 24)
      .overlay {
        Circle().stroke(AppTheme.deepTurquoise, lineWidth: 1)
      }

      VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: 6) {
          Text(reply.nick.isEmpty ? "익명" : reply.nick)
            .pretendard(.captionMeta)
            .foregroundStyle(AppTheme.gray30)
            .lineLimit(1)
            .truncationMode(.tail)
          Text(reply.createdAt.relativeKoreanShort)
            .pretendard(.caption2Bold)
            .foregroundStyle(AppTheme.gray75)

          Spacer(minLength: 0)

          if isReplyOwn {
            Button {
              onReplyEditTapped(reply)
            } label: {
              Image(systemName: "pencil")
                .font(AppTheme.symbol(size: 11, weight: .regular))
                .foregroundStyle(isReplyEditing ? AppTheme.brightTurquoise : AppTheme.gray60)
                .frame(width: 20, height: 18)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("답글 수정")

            Button {
              onReplyDeleteTapped(reply)
            } label: {
              Image(systemName: "trash")
                .font(AppTheme.symbol(size: 11, weight: .regular))
                .foregroundStyle(AppTheme.gray60)
                .frame(width: 20, height: 18)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("답글 삭제")
          }
        }
        Text(reply.content)
          .pretendard(.captionMeta)
          .foregroundStyle(AppTheme.gray60)
          .lineLimit(8)
          .multilineTextAlignment(.leading)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

private extension String {
  /// ISO8601 createdAt 문자열을 한국어 짧은 상대시간으로 변환. 실패 시 원본을 그대로 반환.
  var relativeKoreanShort: String {
    let date = CommentRowDateFormatters.iso.date(from: self)
      ?? CommentRowDateFormatters.isoNoFraction.date(from: self)
    guard let date else { return self }
    let interval = Date().timeIntervalSince(date)
    return CommentRowDateFormatters.relative.localizedString(fromTimeInterval: -max(interval, 0))
  }
}

/// SwiftUI body가 MainActor에서만 호출되므로 단일 스레드 접근만 발생.
private enum CommentRowDateFormatters {
  nonisolated(unsafe) static let iso: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  nonisolated(unsafe) static let isoNoFraction: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()

  nonisolated(unsafe) static let relative: RelativeDateTimeFormatter = {
    let formatter = RelativeDateTimeFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.unitsStyle = .short
    return formatter
  }()
}
