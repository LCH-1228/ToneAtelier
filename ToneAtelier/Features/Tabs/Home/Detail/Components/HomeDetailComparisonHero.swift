//
//  HomeDetailComparisonHero.swift
//  ToneAtelier
//
//  Created by Codex on 4/27/26.
//

import ComposableArchitecture
import SwiftUI

struct HomeDetailComparisonHero: View {
  @Dependency(\.imageClient) private var imageClient

  let isPurchased: Bool
  let splitRatio: Double
  let afterImageURL: String?
  let beforeImageURL: String?
  let splitRatioChanged: (Double) -> Void

  @State private var beforeImage: UIImage?
  @State private var afterImage: UIImage?
  @State private var beforeImageFailed = false
  @State private var afterImageFailed = false

  var body: some View {
    GeometryReader { proxy in
      let splitWidth = proxy.size.width * CGFloat(splitRatio)

      ZStack(alignment: .leading) {
        HomeDetailComparisonImageView(
          image: beforeImage,
          hasFailed: beforeImageFailed
        )
        .frame(width: proxy.size.width, height: proxy.size.height)
        .clipped()

        HomeDetailComparisonImageView(
          image: afterImage,
          hasFailed: afterImageFailed
        )
        .frame(width: proxy.size.width, height: proxy.size.height)
        .frame(width: splitWidth, alignment: .leading)
        .clipped()
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: splitRatio)

        Rectangle()
          .fill(HomeTheme.gray45.opacity(0.8))
          .frame(width: 1)
          .offset(x: splitWidth)
          .animation(.spring(response: 0.4, dampingFraction: 0.8), value: splitRatio)

        Circle()
          .fill(HomeTheme.gray75.opacity(0.7))
          .frame(width: 24, height: 24)
          .overlay {
            Image(AppAsset.HomeDetail.compare)
              .renderingMode(.template)
              .resizable()
              .scaledToFit()
              .foregroundStyle(HomeTheme.gray30)
              .frame(width: 12, height: 12)
          }
          .offset(x: splitWidth - 12)
          .animation(.spring(response: 0.4, dampingFraction: 0.8), value: splitRatio)
      }
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            updateSplitRatio(value.location.x, width: proxy.size.width)
          }
      )
      .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
    .task(id: imageLoadID) {
      await loadComparisonImages()
    }
  }

  private var imageLoadID: String {
    "\(beforeImageURL ?? "")|\(afterImageURL ?? "")"
  }

  private func updateSplitRatio(_ locationX: CGFloat, width: CGFloat) {
    guard width > 0 else { return }
    splitRatioChanged(Double(locationX / width))
  }

  private func loadComparisonImages() async {
    beforeImage = nil
    afterImage = nil
    beforeImageFailed = false
    afterImageFailed = false

    async let beforeResult = loadImage(beforeImageURL)
    async let afterResult = loadImage(afterImageURL)
    let (loadedBefore, loadedAfter) = await (beforeResult, afterResult)

    guard !Task.isCancelled else { return }

    withAnimation(.easeInOut(duration: 0.3)) {
      beforeImage = loadedBefore.image
      afterImage = loadedAfter.image
      beforeImageFailed = loadedBefore.hasFailed
      afterImageFailed = loadedAfter.hasFailed
    }
  }

  private func loadImage(_ urlString: String?) async -> (image: UIImage?, hasFailed: Bool) {
    guard let urlString, !urlString.trimmed.isEmpty else {
      return (nil, true)
    }

    do {
      let data = try await imageClient.fetchData(urlString)
      guard !Task.isCancelled else {
        return (nil, false)
      }

      let image = UIImage(data: data)
      return (image, image == nil)
    } catch {
      guard !Task.isCancelled else {
        return (nil, false)
      }

      return (nil, true)
    }
  }
}
