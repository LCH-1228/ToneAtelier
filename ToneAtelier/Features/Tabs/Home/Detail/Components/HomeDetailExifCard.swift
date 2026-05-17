//
//  HomeDetailExifCard.swift
//  ToneAtelier
//
//  Created by Codex on 4/27/26.
//

import ComposableArchitecture
import SwiftUI

struct HomeDetailExifCard: View {
  let exif: HomeDetailExifInfo

  @Dependency(\.postLocationGeocoder) private var geocoder
  @State private var address: String?

  var body: some View {
    SharedExifInfoCard(
      deviceLine: exif.device,
      cameraLine: exif.cameraLine,
      fileLine: exif.fileLine,
      locationLine: address
    ) {
      HomeDetailExifThumbnailView(coordinate: exif.coordinate)
    }
    .task(id: coordinateKey) {
      guard let coordinate = exif.coordinate else {
        address = nil
        return
      }
      address = try? await geocoder.reverse(coordinate.latitude, coordinate.longitude, .locality)
    }
  }

  private var coordinateKey: String {
    guard let coordinate = exif.coordinate else { return "nil" }
    return String(format: "%.6f,%.6f", coordinate.latitude, coordinate.longitude)
  }
}
