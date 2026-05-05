//
//  HomeAuthorSection.swift
//  ToneAtelier
//
//  Created by Codex on 4/24/26.
//

import SwiftUI

struct HomeAuthorSection: View {
  let author: HomeAuthor

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack(spacing: 12) {
        HomeRemoteImageView(urlString: author.portraitURL)
          .frame(width: 56, height: 56)
          .clipShape(Circle())
          .overlay {
            Circle()
              .stroke(AppTheme.gray75.opacity(0.5), lineWidth: 1)
          }

        VStack(alignment: .leading, spacing: 0) {
          Text(author.name)
            .mulgyeol(.body1)
            .foregroundStyle(AppTheme.gray30)

          Text(author.subtitle)
            .pretendard(.body1)
            .foregroundStyle(AppTheme.gray75)
        }

        Spacer()

        // TODO: CreatorStore 진입 연결
        Button {
        } label: {
          Text("프로필")
            .pretendard(.captionBold)
            .foregroundStyle(AppTheme.gray30)
            .frame(width: 54, height: 32)
            .background(AppTheme.brightTurquoise)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)

        // TODO: 작가 메시지 진입 연결
        Button {
        } label: {
          Image(systemName: "paperplane.fill")
            .resizable()
            .scaledToFit()
            .frame(width: 18, height: 18)
            .foregroundStyle(AppTheme.gray30)
            .frame(width: 32, height: 32)
            .background(AppTheme.deepTurquoise)
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
      }

      HStack(spacing: 12) {
        ForEach(Array(displayGallery.enumerated()), id: \.offset) { _, imageURL in
          HomeRemoteImageView(
            urlString: imageURL,
            placeholderIconName: AppAsset.HomeCategory.landscape
          )
          .frame(maxWidth: .infinity)
          .frame(height: 80)
          .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
      }

      HStack(spacing: 4) {
        ForEach(author.tags, id: \.self) { tag in
          Text(tag)
            .pretendard(.caption1)
            .foregroundStyle(AppTheme.gray60)
            .padding(.horizontal, 14)
            .frame(height: 24)
            .background(AppTheme.blackTurquoise)
            .clipShape(Capsule())
        }
      }

      Text(author.quote)
        .mulgyeol(.caption1)
        .foregroundStyle(AppTheme.gray60)

      Text(author.description)
        .pretendard(.captionParagraph)
        .foregroundStyle(AppTheme.gray60)
    }
  }

  private var displayGallery: [String?] {
    let urls = author.galleryImageURLs.map(Optional.some)
    if urls.count >= 3 {
      return Array(urls.prefix(3))
    }
    return urls + Array(repeating: nil, count: max(0, 3 - urls.count))
  }
}
