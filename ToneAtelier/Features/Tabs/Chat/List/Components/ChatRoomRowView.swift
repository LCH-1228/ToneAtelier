//
//  ChatRoomRowView.swift
//  ToneAtelier
//
//  Created by LCH on 4/29/26.
//

import SwiftUI

/// 채팅방 리스트 행. 상대방 프로필 이미지 + 닉네임 + 마지막 메시지 미리보기 + 시간.
struct ChatRoomRowView: View {
  let room: ChatRoom
  let currentUserID: String?
  let baseURL: URL?

  var body: some View {
    HStack(spacing: 12) {
      avatar
      VStack(alignment: .leading, spacing: 4) {
        HStack(alignment: .firstTextBaseline) {
          Text(opponent?.nick ?? "알 수 없음")
            .font(HomeTheme.pretendard(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
          Spacer(minLength: 8)
          Text(timeText)
            .font(HomeTheme.pretendard(size: 12, weight: .regular))
            .foregroundStyle(HomeTheme.gray60)
        }

        Text(lastMessagePreview)
          .font(HomeTheme.pretendard(size: 14, weight: .regular))
          .foregroundStyle(HomeTheme.gray45)
          .lineLimit(1)
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
      path: opponent?.profileImage,
      baseURL: baseURL,
      shape: .circle,
      placeholder: .person
    )
    .frame(width: 48, height: 48)
  }

  // MARK: - Derived

  private var opponent: ChatUserSummary? {
    if let currentUserID {
      if let other = room.participants.first(where: { $0.user_id != currentUserID }) {
        return other
      }
    }
    return room.participants.first
  }

  private var timeText: String {
    let date = ChatDateUtilities.parseISO8601(room.updatedAt)
    return ChatDateUtilities.relativeListTimeText(for: date)
  }

  private var lastMessagePreview: String {
    if let content = room.lastChat?.content, !content.isEmpty {
      return content
    }
    if room.lastChat?.files?.isEmpty == false {
      return "사진"
    }
    return "대화를 시작해 보세요"
  }
}

#Preview {
  ZStack {
    HomeTheme.background.ignoresSafeArea()
    VStack {
      ChatRoomRowView(
        room: ChatRoom(
          room_id: "room-1",
          createdAt: "2026-04-28T10:00:00.000Z",
          updatedAt: "2026-04-29T08:30:00.000Z",
          participants: [
            ChatUserSummary(
              user_id: "me",
              nick: "나",
              name: nil,
              introduction: nil,
              profileImage: nil,
              hashTags: nil
            ),
            ChatUserSummary(
              user_id: "other",
              nick: "토니",
              name: nil,
              introduction: nil,
              profileImage: nil,
              hashTags: nil
            )
          ],
          lastChat: ChatMessage(
            chat_id: "chat-1",
            room_id: "room-1",
            content: "안녕하세요! 필터 잘 받았습니다",
            createdAt: "2026-04-29T08:30:00.000Z",
            updatedAt: nil,
            sender: ChatUserSummary(
              user_id: "other",
              nick: "토니",
              name: nil,
              introduction: nil,
              profileImage: nil,
              hashTags: nil
            ),
            files: nil
          )
        ),
        currentUserID: "me",
        baseURL: URL(string: "https://example.com/")
      )
    }
  }
  .preferredColorScheme(.dark)
}
