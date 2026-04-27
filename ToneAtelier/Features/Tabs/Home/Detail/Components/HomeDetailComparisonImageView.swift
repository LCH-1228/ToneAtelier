//
//  HomeDetailComparisonImageView.swift
//  ToneAtelier
//
//  Created by Codex on 4/27/26.
//

import SwiftUI

struct HomeDetailComparisonImageView: View {
  let image: UIImage?
  let hasFailed: Bool

  var body: some View {
    Group {
      if let image {
        Image(uiImage: image)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .transition(.opacity)
      } else {
        LinearGradient(
          colors: [
            HomeTheme.deepTurquoise,
            HomeTheme.blackTurquoise,
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        .overlay {
          if hasFailed {
            Image(AppAsset.HomeCategory.star)
              .renderingMode(.template)
              .resizable()
              .scaledToFit()
              .frame(width: 28, height: 28)
              .foregroundStyle(HomeTheme.gray45.opacity(0.9))
          } else {
            ProgressView()
              .tint(HomeTheme.gray45.opacity(0.8))
          }
        }
        .transition(.opacity)
      }
    }
  }
}
