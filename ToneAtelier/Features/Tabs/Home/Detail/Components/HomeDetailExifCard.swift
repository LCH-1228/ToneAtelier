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
    SharedExifInfoCard(
      deviceLine: exif.device,
      cameraLine: exif.cameraLine,
      fileLine: exif.fileLine,
      locationLine: exif.locationLine
    ) {
      HomeDetailExifThumbnailView(coordinate: exif.coordinate)
    }
  }
}
