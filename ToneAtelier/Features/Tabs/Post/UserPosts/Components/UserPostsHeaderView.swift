//
//  UserPostsHeaderView.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//
//  Pencil node: c9c7EM (u_head)
//

import SwiftUI

struct UserPostsHeaderView: View {
  let nickname: String
  let introduction: String?
  let profileImagePath: String?
  let hashTags: [String]
  let onProfileTap: () -> Void

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      avatar

      VStack(alignment: .leading, spacing: 5) {
        Text(nickname)
          .mulgyeol(.smallTitle)
          .foregroundStyle(AppTheme.gray30)
          .lineLimit(1)

        Text(metaText)
          .pretendard(.captionMeta)
          .foregroundStyle(AppTheme.gray75)
          .lineLimit(2)
      }

      Spacer(minLength: 0)

      Button(action: onProfileTap) {
        Text("프로필")
          .pretendard(.captionBold)
          .foregroundStyle(AppTheme.gray30)
          .frame(width: 62, height: 32)
          .background(AppTheme.brightTurquoise)
          .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      }
      .buttonStyle(.plain)
    }
    .padding(14)
    .background(AppTheme.blackTurquoise)
    .overlay {
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(AppTheme.deepTurquoise, lineWidth: 1)
    }
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private var avatar: some View {
    ZStack {
      Circle().fill(AppTheme.deepTurquoise)
      ChatImageView(
        path: profileImagePath,
        baseURL: nil,
        shape: .circle,
        placeholder: .person
      )
      .frame(width: 56, height: 56)
      .clipShape(Circle())
    }
    .frame(width: 56, height: 56)
    .overlay {
      Circle().stroke(AppTheme.brightTurquoise, lineWidth: 2)
    }
  }

  private var metaText: String {
    let trimmedIntro = introduction?.trimmingCharacters(in: .whitespacesAndNewlines)
    if let trimmedIntro, !trimmedIntro.isEmpty {
      return trimmedIntro
    }
    if !hashTags.isEmpty {
      return hashTags.map { "#\($0)" }.joined(separator: " ")
    }
    return "작품을 모아 보여드릴게요"
  }
}
