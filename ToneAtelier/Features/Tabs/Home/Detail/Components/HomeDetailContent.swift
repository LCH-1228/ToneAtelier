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
  let comparisonSplitRatio: Double
  let comparisonSplitRatioChanged: (Double) -> Void
  let authorName: String
  let authorSubtitle: String
  let authorProfileImageURL: String?
  let authorTags: [String]
  let exif: HomeDetailExifInfo
  let presets: [HomeDetailPreset]
  let comments: [FilterCommentResponseDTO]
  let purchaseButtonTapped: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HomeDetailComparisonHero(
        isPurchased: isPurchased,
        splitRatio: comparisonSplitRatio,
        afterImageURL: afterImageURL,
        beforeImageURL: beforeImageURL,
        splitRatioChanged: comparisonSplitRatioChanged
      )
      .frame(height: 384)
      .padding(.top, 8)

      HomeDetailComparisonControl(
        splitRatio: comparisonSplitRatio,
        splitRatioChanged: comparisonSplitRatioChanged
      )
      .frame(height: 24)
      .padding(.top, 12)

      HomeDetailDivider()
        .padding(.top, 8)

      HomeDetailPriceView(price: price)
        .padding(.top, 24)

      HStack(spacing: 8) {
        // 상세 로드 전(buyerCount == 0)에는 "0+"가 노출되지 않도록 placeholder로 표기한다.
        HomeDetailStatCard(title: "다운로드", value: buyerCount > 0 ? "\(buyerCount)+" : "—")
        HomeDetailStatCard(title: "찜하기", value: likeCount.map { "\($0)" } ?? "—")
      }
      .padding(.top, 20)

      HomeDetailExifCard(exif: exif)
        .padding(.top, 20)

      HomeDetailPresetSection(
        isPurchased: isPurchased,
        presets: presets
      )
        .padding(.top, 20)

      HomeDetailPurchaseButton(
        isPurchased: isPurchased,
        action: purchaseButtonTapped
      )
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
        .pretendard(.captionParagraph)
        .foregroundStyle(AppTheme.gray60)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 16)

      if !comments.isEmpty {
        HomeDetailCommentsSection(comments: comments)
          .padding(.top, 24)
      }
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
