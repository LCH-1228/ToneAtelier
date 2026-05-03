//
//  PostLocationGeocoder.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//

import ComposableArchitecture
import CoreLocation
import Foundation

/// 게시글 위치 선택 화면 전용 지오코딩 dependency.
/// CLGeocoder를 wrap해 forward / reverse를 분리 노출한다. 외부 SPM 추가 없이 시스템 API만 사용.
struct PostLocationGeocoder: Sendable {
  var forward: @Sendable (_ query: String) async throws -> GeocodedPlace
  var reverse: @Sendable (_ latitude: Double, _ longitude: Double) async throws -> String?
}

extension PostLocationGeocoder: DependencyKey {
  static let liveValue: PostLocationGeocoder = PostLocationGeocoder(
    forward: { query in
      let geocoder = CLGeocoder()
      let placemarks: [CLPlacemark]
      do {
        placemarks = try await geocoder.geocodeAddressString(query)
      } catch {
        throw PostLocationGeocoderError.network
      }
      guard let placemark = placemarks.first, let coordinate = placemark.location?.coordinate else {
        throw PostLocationGeocoderError.notFound
      }
      return GeocodedPlace(
        latitude: coordinate.latitude,
        longitude: coordinate.longitude,
        address: formattedAddress(placemark)
      )
    },
    reverse: { latitude, longitude in
      let location = CLLocation(latitude: latitude, longitude: longitude)
      let geocoder = CLGeocoder()
      let placemarks: [CLPlacemark]
      do {
        placemarks = try await geocoder.reverseGeocodeLocation(location)
      } catch {
        throw PostLocationGeocoderError.network
      }
      guard let placemark = placemarks.first else { return nil }
      return formattedAddress(placemark)
    }
  )

  static let testValue = PostLocationGeocoder(
    forward: { _ in throw PostLocationGeocoderError.notFound },
    reverse: { _, _ in nil }
  )
}

extension DependencyValues {
  var postLocationGeocoder: PostLocationGeocoder {
    get { self[PostLocationGeocoder.self] }
    set { self[PostLocationGeocoder.self] = newValue }
  }
}

/// CLPlacemark 컴포넌트를 한국어 주소 형태로 조립.
/// addressDictionary가 deprecated이므로 컴포넌트 직접 결합. SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor
/// 환경에서 @Sendable 클로저가 호출할 수 있도록 nonisolated 명시.
private nonisolated func formattedAddress(_ placemark: CLPlacemark) -> String? {
  let parts: [String?] = [
    placemark.administrativeArea,
    placemark.locality,
    placemark.subLocality,
    placemark.thoroughfare,
    placemark.subThoroughfare
  ]
  let trimmed = parts
    .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
    .filter { !$0.isEmpty }
  if trimmed.isEmpty {
    return placemark.name
  }
  return trimmed.joined(separator: " ")
}
