//
//  HomeDetailExifThumbnailView.swift
//  ToneAtelier
//
//  Created by Codex on 4/27/26.
//

import SwiftUI

struct HomeDetailExifThumbnailView: View {
  let coordinate: HomeDetailCoordinate?

  var body: some View {
    Group {
      if let coordinate {
        HomeDetailMapThumbnail(coordinate: coordinate)
      } else {
        VStack(spacing: 2) {
          Image(AppAsset.HomeDetail.noLocation)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 24, height: 24)

          Text("No Location")
            .font(HomeTheme.pretendard(size: 10, weight: .semibold))
        }
        .foregroundStyle(HomeTheme.deepTurquoise)
        .frame(width: 76, height: 76)
        .background(HomeTheme.blackTurquoise)
      }
    }
    .overlay {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .stroke(HomeTheme.deepTurquoise, lineWidth: 2)
    }
    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
  }
}
