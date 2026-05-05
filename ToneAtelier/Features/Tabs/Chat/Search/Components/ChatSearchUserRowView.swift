//
//  ChatSearchUserRowView.swift
//  ToneAtelier
//
//  Created by LCH on 4/29/26.
//

import SwiftUI

struct ChatSearchUserRowView: View {
  let user: ChatUserSummary
  let baseURL: URL?
  let isCreatingRoom: Bool
  let profileAction: () -> Void
  let chatAction: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      avatar
      VStack(alignment: .leading, spacing: 4) {
        Text(user.nick)
          .pretendard(.body1)
          .foregroundStyle(.white)
          .lineLimit(1)

        if let name = user.name, !name.isEmpty {
          Text(name)
            .pretendard(.captionMeta)
            .foregroundStyle(AppTheme.gray45)
            .lineLimit(1)
        }

        if let introduction = user.introduction, !introduction.isEmpty {
          Text(introduction)
            .pretendard(.body3)
            .foregroundStyle(AppTheme.gray60)
            .lineLimit(1)
        }
      }
      Spacer(minLength: 8)

      HStack(spacing: 6) {
        actionButton(title: "프로필", systemImage: nil, action: profileAction)
        actionButton(title: "채팅", systemImage: "paperplane.fill", action: chatAction)
          .disabled(isCreatingRoom)
      }
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

  @ViewBuilder
  private func actionButton(
    title: String,
    systemImage: String?,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 4) {
        if let systemImage {
          Image(systemName: systemImage)
            .font(AppTheme.symbol(size: 12, weight: .medium))
        }
        Text(title)
          .pretendard(.captionMeta)
      }
      .foregroundStyle(.white)
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(Capsule().fill(AppTheme.deepTurquoise))
    }
    .buttonStyle(.plain)
  }
}

#Preview {
  ZStack {
    AppTheme.background.ignoresSafeArea()
    VStack(spacing: 0) {
      ChatSearchUserRowView(
        user: ChatUserSummary(
          userID: "u1",
          nick: "윤새싹",
          name: "SESAC YOON",
          introduction: "맑고 투명한 자연광 톤을 만듭니다",
          profileImage: nil,
          hashTags: nil
        ),
        baseURL: URL(string: "https://example.com/"),
        isCreatingRoom: false,
        profileAction: {},
        chatAction: {}
      )
      ChatSearchUserRowView(
        user: ChatUserSummary(
          userID: "u2",
          nick: "에디",
          name: nil,
          introduction: nil,
          profileImage: nil,
          hashTags: nil
        ),
        baseURL: URL(string: "https://example.com/"),
        isCreatingRoom: false,
        profileAction: {},
        chatAction: {}
      )
    }
  }
  .preferredColorScheme(.dark)
}
