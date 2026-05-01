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

        VStack(alignment: .leading, spacing: 8) {
          Text(author.name)
            .font(AppTheme.mulgyeol(size: 20, weight: .bold))
            .foregroundStyle(AppTheme.gray30)

          Text(author.subtitle)
            .font(AppTheme.pretendard(size: 16, weight: .medium))
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
            .font(AppTheme.pretendard(size: 12, weight: .medium))
            .foregroundStyle(AppTheme.gray60)
            .padding(.horizontal, 14)
            .frame(height: 24)
            .background(AppTheme.blackTurquoise)
            .clipShape(Capsule())
        }
      }

      Text(author.quote)
        .font(AppTheme.pretendard(size: 14, weight: .medium))
        .foregroundStyle(AppTheme.gray60)

      Text(author.description)
        .font(AppTheme.pretendard(size: 12, weight: .regular))
        .foregroundStyle(AppTheme.gray60)
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
