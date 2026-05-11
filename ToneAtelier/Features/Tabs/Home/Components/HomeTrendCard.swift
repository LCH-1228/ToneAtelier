//
//  HomeTrendCard.swift
//  ToneAtelier
//
//  Created by Codex on 4/24/26.
//

import SwiftUI

struct HomeTrendCard: View {
  let trend: HomeTrend
  let isFocused: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      ZStack(alignment: .topLeading) {
        CachedImageView(
          urlString: trend.imageURL,
          placeholderIconName: AppAsset.HomeCategory.star
        )
          .frame(width: 200, height: 240)
          .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
              .fill(.black.opacity(isFocused ? 0.04 : 0.42))
          }
          .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

        Text(trend.title)
          .mulgyeol(.caption1)
          .foregroundStyle(AppTheme.gray30)
          .lineLimit(2)
          .minimumScaleFactor(0.8)
          .padding(.leading, 12)
          .padding(.trailing, 12)
          .padding(.top, 8)

        HStack(spacing: 2) {
          Image(AppAsset.Common.heartFilled)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 13, height: 13)
            .foregroundStyle(AppTheme.gray30)

          Text("\(trend.likeCount)")
            .pretendard(.caption1)
            .foregroundStyle(AppTheme.gray30)
        }
        .padding(.trailing, 10)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
      }
      .opacity(isFocused ? 1 : 0.34)
    }
    .buttonStyle(.plain)
  }
}
