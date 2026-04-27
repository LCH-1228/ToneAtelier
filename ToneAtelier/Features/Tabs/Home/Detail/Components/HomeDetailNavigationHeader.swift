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
  let isLikeRequestInFlight: Bool
  let likeAction: () -> Void

  var body: some View {
    HStack {
      SharedIconButton(
        accessibilityLabel: "뒤로 가기",
        action: backAction
      ) {
        Image(systemName: "chevron.left")
          .font(.system(size: 26, weight: .medium))
          .foregroundStyle(HomeTheme.gray75)
      }

      Spacer()

      Text(displayTitle)
        .font(HomeTheme.mulgyeol(size: 20, weight: .bold))
        .foregroundStyle(HomeTheme.gray60)
        .lineLimit(1)

      Spacer()

      SharedIconButton(
        accessibilityLabel: isLiked ? "좋아요 취소" : "좋아요",
        isDisabled: isLikeRequestInFlight,
        action: likeAction
      ) {
        Image(isLiked ? AppAsset.Common.heartFilled : AppAsset.Common.heartOutline)
          .renderingMode(.template)
          .resizable()
          .scaledToFit()
          .foregroundStyle(HomeTheme.gray60)
          .frame(width: 24, height: 24)
      }
    }
    .frame(height: 56)
    .padding(.horizontal, 4)
  }

  private var displayTitle: String {
    title.isEmpty ? "청록새록" : title
  }
}
