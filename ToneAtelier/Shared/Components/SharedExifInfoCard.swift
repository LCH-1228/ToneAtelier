//
//  SharedExifInfoCard.swift
//  ToneAtelier
//
//  Created by Codex on 4/28/26.
//

import SwiftUI

struct SharedExifInfoCard<Thumbnail: View>: View {
  let deviceLine: String
  let cameraLine: String
  let fileLine: String
  let locationLine: String?
  let thumbnail: Thumbnail

  init(
    deviceLine: String,
    cameraLine: String,
    fileLine: String,
    locationLine: String?,
    @ViewBuilder thumbnail: () -> Thumbnail
  ) {
    self.deviceLine = deviceLine
    self.cameraLine = cameraLine
    self.fileLine = fileLine
    self.locationLine = locationLine
    self.thumbnail = thumbnail()
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text(deviceLine)
          .lineLimit(1)
          .truncationMode(.tail)
          .frame(maxWidth: .infinity, alignment: .leading)

        Text("EXIF")
          .lineLimit(1)
      }
      .font(HomeTheme.pretendard(size: 12, weight: .semibold))
      .foregroundStyle(HomeTheme.deepTurquoise)
      .padding(.horizontal, 12)
      .frame(height: 28)
      .background(HomeTheme.blackTurquoise.opacity(0.92))
      .clipShape(
        UnevenRoundedRectangle(
          topLeadingRadius: 8,
          bottomLeadingRadius: 0,
          bottomTrailingRadius: 0,
          topTrailingRadius: 8,
          style: .continuous
        )
      )

      HStack(spacing: 16) {
        thumbnail
          .frame(width: 76, height: 76)
          .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
          .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
              .stroke(HomeTheme.deepTurquoise, lineWidth: 2)
          }

        VStack(alignment: .leading, spacing: 8) {
          exifText(cameraLine)
          exifText(fileLine)

          if let locationLine {
            exifText(locationLine)
          }
        }
        .font(HomeTheme.pretendard(size: 12, weight: .semibold))
        .foregroundStyle(HomeTheme.gray75)
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(1)
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
    .frame(height: 120)
    .clipped()
  }

  private func exifText(_ text: String) -> some View {
    Text(text)
      .lineLimit(1)
      .truncationMode(.tail)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}
