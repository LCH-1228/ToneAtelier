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
          .font(HomeTheme.pretendard(size: 16, weight: .semibold))
          .foregroundStyle(.white)
          .lineLimit(1)

        if let introduction = user.introduction, !introduction.isEmpty {
          Text(introduction)
            .font(HomeTheme.pretendard(size: 13, weight: .regular))
            .foregroundStyle(HomeTheme.gray60)
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
    if let url = profileImageURL {
      AsyncImage(url: url) { phase in
        switch phase {
        case let .success(image):
          image.resizable().scaledToFill()
        default:
          avatarPlaceholder
        }
      }
      .frame(width: 48, height: 48)
      .clipShape(Circle())
    } else {
      avatarPlaceholder
    }
  }

  private var avatarPlaceholder: some View {
    ZStack {
      Circle().fill(HomeTheme.deepTurquoise)
      Image(systemName: "person.fill")
        .foregroundStyle(HomeTheme.gray60)
        .font(.system(size: 22))
    }
    .frame(width: 48, height: 48)
  }

  // MARK: - Derived

  private var profileImageURL: URL? {
    guard
      let path = user.profileImage,
      !path.isEmpty
    else { return nil }

    if let direct = URL(string: path), direct.scheme != nil {
      return direct
    }
    guard let baseURL else { return nil }
    let normalized = path.hasPrefix("/") ? String(path.dropFirst()) : path
    return URL(string: normalized, relativeTo: baseURL)?.absoluteURL
  }
}

#Preview {
  ZStack {
    HomeTheme.background.ignoresSafeArea()
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
