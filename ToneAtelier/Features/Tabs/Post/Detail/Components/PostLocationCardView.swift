//
//  PostLocationCardView.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//
//  Pencil node: YEHZL (postLocationCard)
//

import ComposableArchitecture
import MapKit
import SwiftUI

/// Detail 위치 카드. 게시글 좌표를 Apple 지도(MapKit `Map`)로 표시하고 핀을 찍는다.
struct PostLocationCardView: View {
  let geolocation: GeolocationDTO

  @Dependency(\.postLocationGeocoder) private var geocoder
  @State private var address: String?

  private var coordinate: CLLocationCoordinate2D {
    CLLocationCoordinate2D(latitude: geolocation.latitude, longitude: geolocation.longitude)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      header
      mapView
      if let address {
        addressLine(address)
      }
    }
    .padding(12)
    .background(AppTheme.blackTurquoise)
    .overlay {
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(AppTheme.deepTurquoise, lineWidth: 1)
    }
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .task(id: coordinateKey) {
      // 좌표가 바뀌면 다시 변환. 실패는 silent — 라인 미표시 유지.
      address = try? await geocoder.reverse(geolocation.latitude, geolocation.longitude, .locality)
    }
  }

  private var coordinateKey: String {
    String(format: "%.6f,%.6f", geolocation.latitude, geolocation.longitude)
  }

  private func addressLine(_ text: String) -> some View {
    Text(text)
      .pretendard(.captionMeta)
      .foregroundStyle(AppTheme.gray60)
      .lineLimit(1)
      .truncationMode(.tail)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var header: some View {
    HStack(spacing: 8) {
      Image(systemName: "mappin.and.ellipse")
        .font(AppTheme.symbol(size: 16, weight: .regular))
        .foregroundStyle(AppTheme.brightTurquoise)
      Text("위치")
        .pretendard(.captionBold)
        .foregroundStyle(AppTheme.gray30)
      Spacer(minLength: 0)
    }
    .frame(height: 24)
  }

  private var mapView: some View {
    Map(initialPosition: .region(initialRegion)) {
      Marker("", coordinate: coordinate)
        .tint(AppTheme.brightTurquoise)
    }
    .mapStyle(.standard(elevation: .flat))
    .allowsHitTesting(false)
    .frame(height: 120)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
  }

  private var initialRegion: MKCoordinateRegion {
    MKCoordinateRegion(
      center: coordinate,
      span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
    )
  }
}
