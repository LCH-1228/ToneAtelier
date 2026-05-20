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
      .fill(AppTheme.gray75.opacity(0.45))
      .frame(height: 1)
  }
}

struct HomeDetailPriceView: View {
  let price: Int

  var body: some View {
    HStack(alignment: .lastTextBaseline, spacing: 6) {
      // 상세 로드 전(price == 0)에는 0원 금액이 그대로 노출되지 않도록 placeholder 표기로 분기한다.
      Text(price > 0 ? price.formatted() : "—")
        .mulgyeol(.display)
        .foregroundStyle(AppTheme.gray30)

      Text("Coin")
        .mulgyeol(.bodyNormal)
        .foregroundStyle(AppTheme.gray75)
    }
  }
}

struct HomeDetailStatCard: View {
  let title: String
  let value: String

  var body: some View {
    VStack(spacing: 4) {
      Text(title)
        .pretendard(.caption1)
        .foregroundStyle(AppTheme.gray75)

      Text(value)
        .pretendard(.title1)
        .foregroundStyle(AppTheme.gray30)
    }
    .frame(width: 99, height: 56)
    .background(AppTheme.blackTurquoise)
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
          .pretendard(.caption1)
          .foregroundStyle(AppTheme.gray60)
          .frame(width: 64, height: 24)
          .background(AppTheme.blackTurquoise)
          .clipShape(Capsule())
      }
    }
  }
}
