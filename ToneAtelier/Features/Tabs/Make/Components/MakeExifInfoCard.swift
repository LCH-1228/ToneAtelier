//
//  MakeExifInfoCard.swift
//  ToneAtelier
//
//  Created by Codex on 4/27/26.
//

import SwiftUI
import UIKit

struct MakeExifInfoCard: View {
  let photo: MakeFeature.RegisteredPhoto

  var body: some View {
    SharedExifInfoCard(
      deviceLine: photo.exif.deviceLine,
      cameraLine: photo.exif.cameraLine,
      fileLine: photo.exif.fileLine,
      locationLine: photo.exif.locationLine
    ) {
      exifThumbnail
    }
  }

  private var exifThumbnail: some View {
    Group {
      if let image = UIImage(data: photo.thumbnailImageData) {
        Image(uiImage: image)
          .resizable()
          .scaledToFill()
          .frame(width: 76, height: 76)
          .clipped()
      } else {
        HomeTheme.deepTurquoise
      }
    }
  }
}
