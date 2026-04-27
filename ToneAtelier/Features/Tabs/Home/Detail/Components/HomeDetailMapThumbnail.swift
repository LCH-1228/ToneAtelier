//
//  HomeDetailMapThumbnail.swift
//  ToneAtelier
//
//  Created by Codex on 4/27/26.
//

import MapKit
import SwiftUI

struct HomeDetailMapThumbnail: View {
  let coordinate: HomeDetailCoordinate

  var body: some View {
    ZStack {
      HomeTheme.blackTurquoise

      ProgressView()
        .tint(HomeTheme.deepTurquoise.opacity(0.5))

      Map(position: .constant(.region(region))) {
        Annotation("촬영 위치", coordinate: coordinate.locationCoordinate) {
          Circle()
            .fill(HomeTheme.brightTurquoise)
            .frame(width: 8, height: 8)
            .overlay(Circle().stroke(.white, lineWidth: 1))
            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
        }
      }
      .mapStyle(.standard)
      .allowsHitTesting(false)
    }
    .frame(width: 76, height: 76)
  }

  private var region: MKCoordinateRegion {
    MKCoordinateRegion(
      center: coordinate.locationCoordinate,
      span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
    )
  }
}

private extension HomeDetailCoordinate {
  var locationCoordinate: CLLocationCoordinate2D {
    CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
  }
}
