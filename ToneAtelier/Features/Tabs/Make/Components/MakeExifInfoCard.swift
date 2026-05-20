//
//  MakeExifInfoCard.swift
//  ToneAtelier
//
//  Created by Codex on 4/27/26.
//

import ComposableArchitecture
import SwiftUI
import UIKit

struct MakeExifInfoCard: View {
  let photo: MakeFeature.RegisteredPhoto

  @Dependency(\.postLocationGeocoder) private var geocoder
  @State private var address: String?

  var body: some View {
    SharedExifInfoCard(
      deviceLine: photo.exif.deviceLine,
      cameraLine: photo.exif.cameraLine,
      fileLine: photo.exif.fileLine,
      locationLine: address
    ) {
      exifThumbnail
    }
    .task(id: coordinateKey) {
      guard let latitude = photo.metadata.latitude,
            let longitude = photo.metadata.longitude else {
        address = nil
        return
      }
      address = try? await geocoder.reverse(latitude, longitude, .locality)
    }
  }

  private var coordinateKey: String {
    guard let latitude = photo.metadata.latitude,
          let longitude = photo.metadata.longitude else { return "nil" }
    return String(format: "%.6f,%.6f", latitude, longitude)
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
        AppTheme.deepTurquoise
      }
    }
  }
}
