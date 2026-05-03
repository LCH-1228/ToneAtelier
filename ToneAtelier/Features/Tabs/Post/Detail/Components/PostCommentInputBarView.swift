//
//  PostCommentInputBarView.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//
//  Pencil node: NDTe4 (d_input) + ANaU6 (replyInputMode)
//

import SwiftUI

struct PostCommentInputBarView: View {
  @Binding var text: String
  let isSubmitting: Bool
  let replyTargetNickname: String?
  var isFocused: FocusState<Bool>.Binding?
  let onSubmit: () -> Void
  let onReplyDismiss: () -> Void

  init(
    text: Binding<String>,
    isSubmitting: Bool,
    replyTargetNickname: String?,
    isFocused: FocusState<Bool>.Binding? = nil,
    onSubmit: @escaping () -> Void,
    onReplyDismiss: @escaping () -> Void
  ) {
    self._text = text
    self.isSubmitting = isSubmitting
    self.replyTargetNickname = replyTargetNickname
    self.isFocused = isFocused
    self.onSubmit = onSubmit
    self.onReplyDismiss = onReplyDismiss
  }

  private var canSend: Bool {
    !isSubmitting && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    VStack(spacing: 8) {
      if let replyTargetNickname {
        replyModeBar(nickname: replyTargetNickname)
      }
      inputBar
    }
  }

  private func replyModeBar(nickname: String) -> some View {
    HStack(spacing: 8) {
      Image(systemName: "arrow.turn.down.right")
        .font(AppTheme.symbol(size: 12, weight: .regular))
        .foregroundStyle(AppTheme.brightTurquoise)
      Text("\(nickname)에게 답글 작성 중")
        .font(AppTheme.pretendard(size: 12, weight: .bold))
        .foregroundStyle(AppTheme.gray30)
        .frame(maxWidth: .infinity, alignment: .leading)
      Button(action: onReplyDismiss) {
        Image(systemName: "xmark")
          .font(AppTheme.symbol(size: 12, weight: .regular))
          .foregroundStyle(AppTheme.gray60)
          .frame(width: 24, height: 24)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("답글 모드 닫기")
      .accessibilityIdentifier("post_detail_reply_dismiss_button")
    }
    .padding(.horizontal, 14)
    .frame(height: 30)
    .background(AppTheme.deepTurquoise)
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
  }

  @ViewBuilder
  private var inputBar: some View {
    HStack(spacing: 8) {
      textFieldContent
      submitButton
    }
    .padding(.horizontal, 14)
    .frame(minHeight: 44)
    .background(AppTheme.blackTurquoise)
    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
  }

  @ViewBuilder
  private var textFieldContent: some View {
    let placeholder = replyTargetNickname == nil ? "댓글을 입력하세요" : "답글을 입력하세요"
    if let isFocused {
      TextField(placeholder, text: $text, axis: .vertical)
        .focused(isFocused)
        .font(AppTheme.pretendard(size: 13, weight: .medium))
        .foregroundStyle(AppTheme.gray30)
        .tint(AppTheme.gray30)
        .lineLimit(1...4)
        .padding(.vertical, 4)
        .accessibilityIdentifier("post_detail_comment_input")
    } else {
      TextField(placeholder, text: $text, axis: .vertical)
        .font(AppTheme.pretendard(size: 13, weight: .medium))
        .foregroundStyle(AppTheme.gray30)
        .tint(AppTheme.gray30)
        .lineLimit(1...4)
        .padding(.vertical, 4)
        .accessibilityIdentifier("post_detail_comment_input")
    }
  }

  @ViewBuilder
  private var submitButton: some View {
    Button(action: onSubmit) {
      ZStack {
        if isSubmitting {
          ProgressView()
            .progressViewStyle(.circular)
            .tint(AppTheme.brightTurquoise)
        } else {
          Image(systemName: "paperplane.fill")
            .font(AppTheme.symbol(size: 16, weight: .regular))
            .foregroundStyle(canSend ? AppTheme.brightTurquoise : AppTheme.gray75)
        }
      }
      .frame(width: 32, height: 32)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .disabled(!canSend)
    .accessibilityLabel("댓글 보내기")
    .accessibilityIdentifier("post_detail_comment_submit_button")
  }
}
