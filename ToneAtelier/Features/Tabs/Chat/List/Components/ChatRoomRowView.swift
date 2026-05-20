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
  let unreadCount: Int
  let currentUserID: String?
  let baseURL: URL?

  init(
    room: ChatRoom,
    unreadCount: Int = 0,
    currentUserID: String?,
    baseURL: URL?
  ) {
    self.room = room
    self.unreadCount = unreadCount
    self.currentUserID = currentUserID
    self.baseURL = baseURL
  }

  var body: some View {
    HStack(spacing: 12) {
      avatar
      VStack(alignment: .leading, spacing: 4) {
        HStack(alignment: .firstTextBaseline) {
          Text(opponent?.nick ?? "알 수 없음")
            .pretendard(.body1)
            .foregroundStyle(.white)
            .lineLimit(1)
          Spacer(minLength: 8)
          Text(timeText)
            .pretendard(.caption1)
            .foregroundStyle(AppTheme.gray60)
        }

        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text(lastMessagePreview)
            .pretendard(.body2)
            .foregroundStyle(AppTheme.gray45)
            .lineLimit(1)
          Spacer(minLength: 8)
          if unreadCount > 0 {
            unreadBadge
          }
        }
      }
    }
    .padding(.vertical, 10)
    .padding(.horizontal, 16)
    .contentShape(Rectangle())
    .accessibilityLabel(accessibilityText)
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

  @ViewBuilder
  private var unreadBadge: some View {
    Text(unreadDisplayText)
      .pretendard(.captionMeta)
      .foregroundStyle(.white)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .frame(minWidth: 18)
      .background(AppTheme.deepTurquoise, in: Capsule())
  }

  private var unreadDisplayText: String {
    unreadCount > 99 ? "99+" : String(unreadCount)
  }

  private var accessibilityText: String {
    let nick = opponent?.nick ?? "알 수 없음"
    let preview = lastMessagePreview
    if unreadCount > 0 {
      return "\(nick), \(preview), 읽지 않은 메시지 \(unreadCount)건"
    }
    return "\(nick), \(preview)"
  }

  // MARK: - Derived

  private var opponent: ChatUserSummary? {
    if let currentUserID {
      if let other = room.participants.first(where: { $0.userID != currentUserID }) {
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
    AppTheme.background.ignoresSafeArea()
    VStack {
      ChatRoomRowView(
        room: ChatRoom(
          roomID: "room-1",
          createdAt: "2026-04-28T10:00:00.000Z",
          updatedAt: "2026-04-29T08:30:00.000Z",
          participants: [
            ChatUserSummary(
              userID: "me",
              nick: "나",
              name: nil,
              introduction: nil,
              profileImage: nil,
              hashTags: nil
            ),
            ChatUserSummary(
              userID: "other",
              nick: "토니",
              name: nil,
              introduction: nil,
              profileImage: nil,
              hashTags: nil
            )
          ],
          lastChat: ChatMessage(
            chatID: "chat-1",
            roomID: "room-1",
            content: "안녕하세요! 필터 잘 받았습니다",
            createdAt: "2026-04-29T08:30:00.000Z",
            updatedAt: nil,
            sender: ChatUserSummary(
              userID: "other",
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
