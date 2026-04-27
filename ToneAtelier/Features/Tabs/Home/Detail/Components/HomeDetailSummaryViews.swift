//
//  HomeDetailSummaryViews.swift
//  ToneAtelier
//
//  Created by Codex on 4/27/26.
//

import SwiftUI

struct HomeDetailDivider: View {
  var body: some View {
    Rectangle()
      .fill(HomeTheme.gray75.opacity(0.45))
      .frame(height: 1)
  }
}

struct HomeDetailPriceView: View {
  let price: Int

  var body: some View {
    HStack(alignment: .lastTextBaseline, spacing: 6) {
      Text(price.formatted())
        .font(HomeTheme.mulgyeol(size: 32, weight: .bold))
        .foregroundStyle(HomeTheme.gray30)

      Text("Coin")
        .font(HomeTheme.mulgyeol(size: 20, weight: .bold))
        .foregroundStyle(HomeTheme.gray75)
    }
  }
}

struct HomeDetailStatCard: View {
  let title: String
  let value: String

  var body: some View {
    VStack(spacing: 4) {
      Text(title)
        .font(HomeTheme.pretendard(size: 12, weight: .semibold))
        .foregroundStyle(HomeTheme.gray75)

      Text(value)
        .font(HomeTheme.pretendard(size: 20, weight: .bold))
        .foregroundStyle(HomeTheme.gray30)
    }
    .frame(width: 99, height: 56)
    .background(HomeTheme.blackTurquoise)
    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
  }
}

struct HomeDetailPurchaseButton: View {
  let isPurchased: Bool
  let action: () -> Void

  var body: some View {
    SharedPrimaryButton(
      title: isPurchased ? "구매완료" : "결제하기",
      isDisabled: isPurchased,
      action: action
    )
  }
}

struct HomeDetailTagRow: View {
  let tags: [String]

  var body: some View {
    HStack(spacing: 4) {
      ForEach(tags, id: \.self) { tag in
        Text(tag)
          .font(HomeTheme.pretendard(size: 12, weight: .medium))
          .foregroundStyle(HomeTheme.gray60)
          .frame(width: 64, height: 24)
          .background(HomeTheme.blackTurquoise)
          .clipShape(Capsule())
      }
    }
  }
}
