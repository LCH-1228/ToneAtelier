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
      HStack(spacing: 16) {
        HomeRemoteImageView(urlString: author.portraitURL)
          .frame(width: 72, height: 72)
          .clipShape(Circle())
          .overlay {
            Circle()
              .stroke(AppTheme.gray75.opacity(0.5), lineWidth: 1)
          }

        // TODO: 작가 이름 옆에 "작가 필터 보기" 버튼을 추가하고, 해당 버튼 탭 시 CreatorStore 진입을 후속 브랜치에서 연결.
        VStack(alignment: .leading, spacing: 8) {
          Text(author.name)
            .mulgyeol(.bodyNormal)
            .foregroundStyle(AppTheme.gray30)

          Text(author.subtitle)
            .pretendard(.body1)
            .foregroundStyle(AppTheme.gray75)
        }
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
