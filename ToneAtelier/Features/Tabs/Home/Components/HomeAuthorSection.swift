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
      // TODO: profileAction, messageAction 진입 연결
      UserProfileHeader(
        name: author.name,
        subtitle: author.subtitle,
        profileImageURL: author.portraitURL,
        profileAction: {},
        messageAction: {}
      )

      HStack(spacing: 12) {
        ForEach(Array(displayGallery.enumerated()), id: \.offset) { _, imageURL in
          CachedImageView(
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
