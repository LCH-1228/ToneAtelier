//
//  HomeDetailAuthorSection.swift
//  ToneAtelier
//
//  Created by Codex on 4/27/26.
//

import SwiftUI

struct HomeDetailAuthorSection: View {
  let name: String
  let subtitle: String
  let profileImageURL: String?

  var body: some View {
    HStack(spacing: 16) {
      HomeRemoteImageView(
        urlString: profileImageURL,
        contentMode: .fill,
        placeholderIconName: AppAsset.HomeCategory.people
      )
      .frame(width: 72, height: 72)
      .overlay {
        Circle()
          .stroke(HomeTheme.gray75.opacity(0.5), lineWidth: 1)
      }
      .clipShape(Circle())

      VStack(alignment: .leading, spacing: 8) {
        Text(name)
          .font(HomeTheme.mulgyeol(size: 20, weight: .bold))
          .foregroundStyle(HomeTheme.gray30)

        Text(subtitle)
          .font(HomeTheme.pretendard(size: 16, weight: .medium))
          .foregroundStyle(HomeTheme.gray75)
      }

      Spacer()

      Button(action: {}) {
        Image(AppAsset.HomeDetail.message)
          .renderingMode(.template)
          .resizable()
          .scaledToFit()
          .foregroundStyle(HomeTheme.gray45)
          .frame(width: 26, height: 26)
          .frame(width: 44, height: 44)
          .background(HomeTheme.deepTurquoise)
          .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
      }
      .buttonStyle(.plain)
    }
  }
}
