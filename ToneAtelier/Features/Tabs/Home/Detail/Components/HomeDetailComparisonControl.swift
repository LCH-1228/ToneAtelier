//
//  HomeDetailComparisonControl.swift
//  ToneAtelier
//
//  Created by Codex on 4/27/26.
//

import SwiftUI

struct HomeDetailComparisonControl: View {
  let splitRatio: Double
  let splitRatioChanged: (Double) -> Void

  var body: some View {
    GeometryReader { proxy in
      let splitX = proxy.size.width * CGFloat(splitRatio)

      ZStack(alignment: .leading) {
        comparisonLabel("After")
          .offset(x: max(0, splitX - 88))

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
          .offset(x: max(0, splitX - 12))

        comparisonLabel("Before")
          .offset(x: min(proxy.size.width - 48, splitX + 32))
      }
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            updateSplitRatio(value.location.x, width: proxy.size.width)
          }
      )
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("비교 위치")
    .accessibilityValue("\(Int((splitRatio * 100).rounded()))%")
    .accessibilityAdjustableAction { direction in
      switch direction {
      case .increment:
        splitRatioChanged(splitRatio + 0.05)
      case .decrement:
        splitRatioChanged(splitRatio - 0.05)
      @unknown default:
        break
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

  private func updateSplitRatio(_ locationX: CGFloat, width: CGFloat) {
    guard width > 0 else { return }
    splitRatioChanged(Double(locationX / width))
  }
}
