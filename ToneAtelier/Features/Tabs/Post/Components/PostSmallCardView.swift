//
//  PostSmallCardView.swift
//  ToneAtelier
//
//  Pencil node: Gl4iD (UserPosts u_card1).
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
          .frame(width: 86, height: 86)
          .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

        VStack(alignment: .leading, spacing: 6) {
          Text(post.title)
            .pretendard(.body2)
            .foregroundStyle(AppTheme.gray30)
            .lineLimit(2)

          Text(metaText)
            .pretendard(.captionMeta)
            .foregroundStyle(AppTheme.gray75)
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(AppTheme.blackTurquoise)
      .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
  }

  private var thumbnail: some View {
    ChatImageView(
      path: post.files.first,
      baseURL: baseURL,
      shape: .roundedRect(cornerRadius: 10)
    )
  }

  private var metaText: String {
    let photoCount = post.files.count
    let likeCount = Int(post.likeCount)
    return "사진 \(photoCount) · 좋아요 \(likeCount)"
  }
}
