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
              .stroke(HomeTheme.gray75.opacity(0.5), lineWidth: 1)
          }

        VStack(alignment: .leading, spacing: 8) {
          Text(author.name)
            .font(HomeTheme.mulgyeol(size: 20, weight: .bold))
            .foregroundStyle(HomeTheme.gray30)

          Text(author.subtitle)
            .font(HomeTheme.pretendard(size: 16, weight: .medium))
            .foregroundStyle(HomeTheme.gray75)
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
            .font(HomeTheme.pretendard(size: 12, weight: .medium))
            .foregroundStyle(HomeTheme.gray60)
            .padding(.horizontal, 14)
            .frame(height: 24)
            .background(HomeTheme.blackTurquoise)
            .clipShape(Capsule())
        }
      }

      Text(author.quote)
        .font(HomeTheme.pretendard(size: 14, weight: .medium))
        .foregroundStyle(HomeTheme.gray60)

      Text(author.description)
        .font(HomeTheme.pretendard(size: 12, weight: .regular))
        .foregroundStyle(HomeTheme.gray60)
        .lineSpacing(6)
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
