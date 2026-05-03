//
//  PostSmallCardView.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//
//  Pencil node: rPoct (Post 작은 카드 — 더보기/관련 항목 노출용)
//

import SwiftUI

struct PostSmallCardView: View {
  let post: PostSummaryResponseDTO
  let baseURL: URL?
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        thumbnail
          .frame(width: 64, height: 64)
          .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

        VStack(alignment: .leading, spacing: 4) {
          Text(post.title)
            .font(AppTheme.pretendard(size: 14, weight: .bold))
            .foregroundStyle(AppTheme.gray30)
            .lineLimit(1)

          Text(metaText)
            .font(AppTheme.pretendard(size: 12, weight: .regular))
            .foregroundStyle(AppTheme.gray60)
            .lineLimit(1)

          Text("더보기로 다음 게시글을 이어서 확인")
            .font(AppTheme.pretendard(size: 12, weight: .regular))
            .foregroundStyle(AppTheme.gray75)
            .lineLimit(1)
        }

        Spacer(minLength: 0)
      }
      .padding(12)
      .background(AppTheme.blackTurquoise)
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
  }

  private var thumbnail: some View {
    ChatImageView(
      path: post.files.first,
      baseURL: baseURL,
      shape: .roundedRect(cornerRadius: 8)
    )
  }

  private var metaText: String {
    let category = post.category.isEmpty ? "기타" : post.category
    let nickname = post.creator.nick.isEmpty ? "익명" : post.creator.nick
    return "\(category) · \(nickname)"
  }
}

#Preview {
  PostSmallCardView(
    post: PostSummaryResponseDTO(
      postID: "preview",
      category: "핫스팟",
      title: "근처에서 인기 있는 게시글",
      content: "",
      geolocation: GeolocationDTO(longitude: 0, latitude: 0),
      creator: UserInfoResponseDTO(
        userID: "u1",
        nick: "맛스푼",
        name: nil,
        introduction: nil,
        profileImage: nil,
        hashTags: nil
      ),
      files: ["dummy.jpg"],
      isLike: false,
      likeCount: 0,
      createdAt: "2026-05-03T12:00:00Z",
      updatedAt: "2026-05-03T12:00:00Z"
    ),
    baseURL: nil,
    action: {}
  )
  .padding(20)
  .background(AppTheme.background)
  .preferredColorScheme(.dark)
}
