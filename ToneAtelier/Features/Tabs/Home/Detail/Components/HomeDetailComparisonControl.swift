//
//  HomeDetailComparisonControl.swift
//  ToneAtelier
//
//  Created by Codex on 4/27/26.
//

import SwiftUI

struct HomeDetailComparisonControl: View {
  let splitRatio: CGFloat

  var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .leading) {
        comparisonLabel("After")
          .offset(x: max(0, proxy.size.width * splitRatio - 88))

        Circle()
          .fill(HomeTheme.gray75.opacity(0.5))
          .frame(width: 24, height: 24)
          .overlay {
            Image(AppAsset.HomeDetail.compare)
              .renderingMode(.template)
              .resizable()
              .scaledToFit()
              .foregroundStyle(HomeTheme.gray45)
              .frame(width: 12, height: 12)
          }
          .offset(x: max(0, proxy.size.width * splitRatio - 12))

        comparisonLabel("Before")
          .offset(x: min(proxy.size.width - 48, proxy.size.width * splitRatio + 32))
      }
    }
  }

  private func comparisonLabel(_ text: String) -> some View {
    Text(text)
      .font(HomeTheme.pretendard(size: 10, weight: .semibold))
      .foregroundStyle(HomeTheme.gray60)
      .frame(width: 48, height: 20)
      .background(HomeTheme.gray75.opacity(0.5))
      .clipShape(Capsule())
  }
}
