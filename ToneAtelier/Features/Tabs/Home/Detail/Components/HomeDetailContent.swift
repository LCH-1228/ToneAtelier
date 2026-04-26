//
//  HomeDetailContent.swift
//  ToneAtelier
//
//  Created by Codex on 4/27/26.
//

import SwiftUI

struct HomeDetailContent: View {
  let summary: String?
  let likeCount: Int?
  let price: Int
  let buyerCount: Int
  let isPurchased: Bool
  let afterImageURL: String?
  let beforeImageURL: String?
  let authorName: String
  let authorSubtitle: String
  let authorProfileImageURL: String?
  let authorTags: [String]
  let exif: HomeDetailExifInfo
  let presets: [HomeDetailPreset]

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HomeDetailComparisonHero(
        isPurchased: isPurchased,
        splitRatio: 0.68,
        afterImageURL: afterImageURL,
        beforeImageURL: beforeImageURL
      )
      .frame(height: 384)
      .padding(.top, 8)

      HomeDetailComparisonControl(
        splitRatio: 0.68
      )
      .frame(height: 24)
      .padding(.top, 12)

      HomeDetailDivider()
        .padding(.top, 8)

      HomeDetailPriceView(price: price)
        .padding(.top, 24)

      HStack(spacing: 8) {
        HomeDetailStatCard(title: "다운로드", value: "\(buyerCount)+")
        HomeDetailStatCard(title: "찜하기", value: "\(likeCount ?? 800)")
      }
      .padding(.top, 20)

      HomeDetailExifCard(exif: exif)
        .padding(.top, 20)

      HomeDetailPresetSection(
        isPurchased: isPurchased,
        presets: presets
      )
        .padding(.top, 20)

      HomeDetailPurchaseButton(isPurchased: isPurchased)
        .padding(.top, 20)

      HomeDetailDivider()
        .padding(.top, 12)

      HomeDetailAuthorSection(
        name: authorName,
        subtitle: authorSubtitle,
        profileImageURL: authorProfileImageURL
      )
        .padding(.top, 20)

      HomeDetailTagRow(tags: authorTags)
        .padding(.top, 20)

      Text(summaryText)
        .font(HomeTheme.pretendard(size: 12, weight: .regular))
        .foregroundStyle(HomeTheme.gray60)
        .lineSpacing(6)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 16)
    }
    .frame(maxWidth: 350, alignment: .leading)
    .padding(.horizontal, 20)
    .frame(maxWidth: .infinity, alignment: .center)
  }

  private var summaryText: String {
    guard let summary, !summary.isEmpty else {
      return HomeDetailDesignData.description
    }

    return summary
  }
}
