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
        HomeDetailExifThumbnailView(coordinate: exif.coordinate)

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
}
