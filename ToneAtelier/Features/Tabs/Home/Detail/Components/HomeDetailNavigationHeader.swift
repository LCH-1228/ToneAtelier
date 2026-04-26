//
//  HomeDetailNavigationHeader.swift
//  ToneAtelier
//
//  Created by Codex on 4/27/26.
//

import SwiftUI

struct HomeDetailNavigationHeader: View {
  let title: String
  let backAction: () -> Void
  let isLiked: Bool
  let likeAction: () -> Void

  var body: some View {
    HStack {
      Button(action: backAction) {
        Image(systemName: "chevron.left")
          .font(.system(size: 26, weight: .medium))
          .foregroundStyle(HomeTheme.gray75)
          .frame(width: 48, height: 56)
      }
      .buttonStyle(.plain)

      Spacer()

      Text(displayTitle)
        .font(HomeTheme.mulgyeol(size: 20, weight: .bold))
        .foregroundStyle(HomeTheme.gray60)
        .lineLimit(1)

      Spacer()

      Button(action: likeAction) {
        Image(isLiked ? AppAsset.Common.heartFilled : AppAsset.Common.heartOutline)
          .renderingMode(.template)
          .resizable()
          .scaledToFit()
          .foregroundStyle(HomeTheme.gray60)
          .frame(width: 24, height: 24)
          .frame(width: 48, height: 56)
      }
      .buttonStyle(.plain)
    }
    .frame(height: 56)
    .padding(.horizontal, 4)
  }

  private var displayTitle: String {
    title.isEmpty ? "청록새록" : title
  }
}
