//
//  HomeDetailPresetSection.swift
//  ToneAtelier
//
//  Created by Codex on 4/27/26.
//

import SwiftUI

struct HomeDetailPresetSection: View {
  let isPurchased: Bool
  let presets: [HomeDetailPreset]

  private let columns = Array(
    repeating: GridItem(.fixed(32), spacing: 20),
    count: 6
  )

  var body: some View {
    VStack(spacing: 0) {
      HomeDetailSectionHeader(
        leading: "Filter Presets",
        trailing: "LUT"
      )

      ZStack {
        presetGrid
          .blur(radius: isPurchased ? 0 : 6)
          .opacity(isPurchased ? 1 : 0.35)
          .accessibilityHidden(!isPurchased)

        if !isPurchased {
          Color(hex: 0x2D3031, opacity: 0.6)
            .accessibilityHidden(true)

          VStack(spacing: 12) {
            Image(AppAsset.HomeDetail.lock)
              .renderingMode(.template)
              .resizable()
              .scaledToFit()
              .frame(width: 24, height: 24)
              .foregroundStyle(HomeTheme.gray45)

            Text("결제가 필요한 유료 필터입니다")
              .font(HomeTheme.pretendard(size: 16, weight: .bold))
              .foregroundStyle(HomeTheme.gray45)
          }
          .accessibilityElement(children: .combine)
          .accessibilityLabel("결제가 필요한 유료 필터입니다")
        }
      }
      .frame(height: 162)
      .frame(maxWidth: .infinity)
      .background(HomeTheme.blackTurquoise)
      .clipShape(
        UnevenRoundedRectangle(
          topLeadingRadius: 0,
          bottomLeadingRadius: 8,
          bottomTrailingRadius: 8,
          topTrailingRadius: 0,
          style: .continuous
        )
      )
    }
  }

  private var presetGrid: some View {
    LazyVGrid(columns: columns, spacing: 13) {
      ForEach(presets) { preset in
        VStack(spacing: 4) {
          Image(preset.assetName)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(HomeTheme.gray75)
            .frame(width: 32, height: 32)

          Text(preset.value)
            .font(HomeTheme.pretendard(size: 14, weight: .bold))
            .foregroundStyle(HomeTheme.gray75)
            .frame(width: 36)
        }
        .frame(width: 44, height: 52)
        .accessibilityLabel("프리셋 값 \(preset.value)")
      }
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 20)
  }
}
