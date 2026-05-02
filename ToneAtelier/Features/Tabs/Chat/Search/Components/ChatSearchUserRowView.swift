//
//  ChatSearchUserRowView.swift
//  ToneAtelier
//
//  Created by LCH on 4/29/26.
//

import SwiftUI

/// 검색 결과 행. 프로필 이미지(48pt 원형) + 닉 + introduction.
struct ChatSearchUserRowView: View {
  let user: ChatUserSummary
  let baseURL: URL?

  var body: some View {
    HStack(spacing: 12) {
      avatar
      VStack(alignment: .leading, spacing: 4) {
        Text(user.nick)
          .font(AppTheme.pretendard(size: 16, weight: .semibold))
          .foregroundStyle(.white)
          .lineLimit(1)

        if let introduction = user.introduction, !introduction.isEmpty {
          Text(introduction)
            .font(AppTheme.pretendard(size: 13, weight: .regular))
            .foregroundStyle(AppTheme.gray60)
            .lineLimit(1)
        }
      }
      Spacer(minLength: 8)
    }
    .padding(.vertical, 10)
    .padding(.horizontal, 16)
    .contentShape(Rectangle())
  }

  // MARK: - Subviews

  @ViewBuilder
  private var avatar: some View {
    ChatImageView(
      path: user.profileImage,
      baseURL: baseURL,
      shape: .circle,
      placeholder: .person
    )
    .frame(width: 48, height: 48)
  }
}

#Preview {
  ZStack {
    AppTheme.background.ignoresSafeArea()
    VStack(spacing: 0) {
      ChatSearchUserRowView(
        user: ChatUserSummary(
          user_id: "u1",
          nick: "토니",
          name: nil,
          introduction: "필름 톤을 만듭니다",
          profileImage: nil,
          hashTags: nil
        ),
        baseURL: URL(string: "https://example.com/")
      )
      ChatSearchUserRowView(
        user: ChatUserSummary(
          user_id: "u2",
          nick: "에디",
          name: nil,
          introduction: nil,
          profileImage: nil,
          hashTags: nil
        ),
        baseURL: URL(string: "https://example.com/")
      )
    }
  }
  .preferredColorScheme(.dark)
}
