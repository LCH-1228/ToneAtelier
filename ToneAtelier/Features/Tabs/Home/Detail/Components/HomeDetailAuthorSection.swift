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
          .stroke(AppTheme.gray75.opacity(0.5), lineWidth: 1)
      }
      .clipShape(Circle())

      VStack(alignment: .leading, spacing: 8) {
        Text(name)
          .mulgyeol(.bodyNormal)
          .foregroundStyle(AppTheme.gray30)

        Text(subtitle)
          .pretendard(.body1)
          .foregroundStyle(AppTheme.gray75)
      }

      Spacer()

      Button(action: {}, label: {
        Image(AppAsset.HomeDetail.message)
          .renderingMode(.template)
          .resizable()
          .scaledToFit()
          .foregroundStyle(AppTheme.gray45)
          .frame(width: 26, height: 26)
          .frame(width: 44, height: 44)
          .background(AppTheme.deepTurquoise)
          .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
      })
      .buttonStyle(.plain)
    }
  }
}
