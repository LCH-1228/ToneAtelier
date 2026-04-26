//
//  HomeDetailExifCard.swift
//  ToneAtelier
//
//  Created by Codex on 4/27/26.
//

import SwiftUI

struct HomeDetailExifCard: View {
  let exif: HomeDetailExifInfo

  var body: some View {
    VStack(spacing: 0) {
      HomeDetailSectionHeader(
        leading: exif.device,
        trailing: "EXIF"
      )

      HStack(spacing: 16) {
        thumbnail

        VStack(alignment: .leading, spacing: 8) {
          Text(exif.cameraLine)
          Text(exif.fileLine)

          if let locationLine = exif.locationLine {
            Text(locationLine)
          }
        }
        .font(HomeTheme.pretendard(size: 12, weight: .semibold))
        .foregroundStyle(HomeTheme.gray75)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(8)
      .frame(height: 92)
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

  @ViewBuilder
  private var thumbnail: some View {
    VStack(spacing: 2) {
      Image(AppAsset.HomeDetail.noLocation)
        .renderingMode(.template)
        .resizable()
        .scaledToFit()
        .frame(width: 24, height: 24)

      Text("No Location")
        .font(HomeTheme.pretendard(size: 10, weight: .semibold))
    }
    .frame(width: 76, height: 76)
    .foregroundStyle(HomeTheme.deepTurquoise)
    .background(HomeTheme.blackTurquoise)
    .overlay {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .stroke(HomeTheme.deepTurquoise, lineWidth: 2)
    }
    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
  }
}

struct HomeDetailSectionHeader: View {
  let leading: String
  let trailing: String

  var body: some View {
    HStack {
      Text(leading)
      Spacer()
      Text(trailing)
    }
    .font(HomeTheme.pretendard(size: 12, weight: .semibold))
    .foregroundStyle(HomeTheme.deepTurquoise)
    .padding(.horizontal, 12)
    .frame(height: 28)
    .background(HomeTheme.blackTurquoise.opacity(0.55))
    .overlay {
      RoundedRectangle(cornerRadius: 4, style: .continuous)
        .stroke(HomeTheme.deepTurquoise.opacity(0.9), lineWidth: 1)
    }
  }
}
