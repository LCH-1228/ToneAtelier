//
//  PostLocationSelectFeature.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//
//  Pencil node: lullK (Post Location Select View)
//

import ComposableArchitecture
import CoreLocation
import Foundation

@Reducer
struct PostLocationSelectFeature {
  @Dependency(\.locationClient) private var locationClient
  @Dependency(\.postLocationGeocoder) private var geocoder
  @Dependency(\.postLocationRecentStore) private var recentStore

  /// 최근 선택 캐시 한도. UserDefaults에 5개까지만 보관.
  static let recentLimit = 5

  /// 좌표만 비교하면 부동 소수 차이로 동일 위치 캐시가 다중 등록될 수 있어 6자리 절단으로 normalize.
  private static let coordinateRoundingScale: Double = 1_000_000

  @ObservableState
  struct State: Equatable {
    var query: String = ""
    /// 사용자가 핀 드래그/검색 결과 적용으로 선택한 좌표.
    var selectedLatitude: Double?
    var selectedLongitude: Double?
    var selectedAddress: String?
    /// 검색/지오코딩 진행 중 표시.
    var isResolving: Bool = false
    var errorMessage: String?
    var recents: [PostLocationRecent] = []

    var canConfirm: Bool {
      selectedLatitude != nil && selectedLongitude != nil
    }

    /// 외부에서 기존 좌표를 미리 채워 진입할 수 있도록.
    init(
      latitude: Double? = nil,
      longitude: Double? = nil,
      address: String? = nil
    ) {
      self.selectedLatitude = latitude
      self.selectedLongitude = longitude
      self.selectedAddress = address
    }
  }

  enum Action: BindableAction, Sendable {
    case binding(BindingAction<State>)
    case task
    case recentsLoaded([PostLocationRecent])
    case querySubmitted
    case forwardGeocodeResponse(query: String, Result<GeocodedPlace, Error>)
    case pinCoordinateChanged(latitude: Double, longitude: Double)
    case reverseGeocodeResponse(latitude: Double, longitude: Double, Result<String?, Error>)
    case useCurrentLocationTapped
    case currentLocationResponse(Result<CLLocationCoordinate2D, Error>)
    case recentTapped(PostLocationRecent)
    case confirmTapped
    case closeTapped
    case delegate(Delegate)

    enum Delegate: Equatable, Sendable {
      case dismiss
      case confirmed(latitude: Double, longitude: Double, address: String?)
    }
  }

  var body: some Reducer<State, Action> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .binding:
        return .none

      case .task:
        let recentStore = recentStore
        return .run { send in
          let recents = await recentStore.load()
          await send(.recentsLoaded(recents))
        }
        .cancellable(id: "PostLocationSelectFeature.recents", cancelInFlight: true)

      case let .recentsLoaded(recents):
        state.recents = recents
        return .none

      case .querySubmitted:
        let trimmed = state.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .none }
        state.isResolving = true
        state.errorMessage = nil

        let geocoder = geocoder
        return .run { send in
          await send(
            .forwardGeocodeResponse(
              query: trimmed,
              Result {
                try await geocoder.forward(trimmed)
              }
            )
          )
        }
        .cancellable(id: "PostLocationSelectFeature.forwardGeocode", cancelInFlight: true)

      case let .forwardGeocodeResponse(_, .success(place)):
        state.isResolving = false
        state.selectedLatitude = place.latitude
        state.selectedLongitude = place.longitude
        state.selectedAddress = place.address ?? state.selectedAddress
        state.errorMessage = nil
        return .none

      case let .forwardGeocodeResponse(_, .failure(error)):
        state.isResolving = false
        state.errorMessage = Self.userFacingMessage(for: error)
        return .none

      case let .pinCoordinateChanged(latitude, longitude):
        state.selectedLatitude = latitude
        state.selectedLongitude = longitude
        state.errorMessage = nil

        let geocoder = geocoder
        return .run { send in
          await send(
            .reverseGeocodeResponse(
              latitude: latitude,
              longitude: longitude,
              Result {
                try await geocoder.reverse(latitude, longitude)
              }
            )
          )
        }
        .cancellable(id: "PostLocationSelectFeature.reverseGeocode", cancelInFlight: true)

      case let .reverseGeocodeResponse(latitude, longitude, .success(address)):
        // 응답 도착 시점에 선택 좌표가 다시 바뀌었으면 폐기.
        guard
          state.selectedLatitude == latitude,
          state.selectedLongitude == longitude
        else {
          return .none
        }
        state.selectedAddress = address
        return .none

      case .reverseGeocodeResponse(_, _, .failure):
        // reverse 지오코딩 실패 시 좌표만 유지하고 주소는 비움.
        state.selectedAddress = nil
        return .none

      case .useCurrentLocationTapped:
        let locationClient = locationClient
        return .run { send in
          let status = await locationClient.currentAuthorizationStatus()
          if status == .notDetermined {
            _ = await locationClient.requestAuthorization()
          }
          await send(
            .currentLocationResponse(
              Result {
                try await locationClient.currentLocation()
              }
            )
          )
        }
        .cancellable(id: "PostLocationSelectFeature.currentLocation", cancelInFlight: true)

      case let .currentLocationResponse(.success(coordinate)):
        return .send(
          .pinCoordinateChanged(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
          )
        )

      case let .currentLocationResponse(.failure(error)):
        state.errorMessage = Self.userFacingMessage(for: error)
        return .none

      case let .recentTapped(recent):
        state.selectedLatitude = recent.latitude
        state.selectedLongitude = recent.longitude
        state.selectedAddress = recent.address
        state.errorMessage = nil
        return .none

      case .confirmTapped:
        guard
          let latitude = state.selectedLatitude,
          let longitude = state.selectedLongitude
        else {
          return .none
        }
        let address = state.selectedAddress
        let recentStore = recentStore
        let snapshot = state.recents
        let updated = Self.upsert(
          recents: snapshot,
          latitude: latitude,
          longitude: longitude,
          address: address
        )
        state.recents = updated

        return .merge(
          .send(.delegate(.confirmed(latitude: latitude, longitude: longitude, address: address))),
          .send(.delegate(.dismiss)),
          .run { _ in
            await recentStore.save(updated)
          }
        )

      case .closeTapped:
        return .send(.delegate(.dismiss))

      case .delegate:
        return .none
      }
    }
  }

  /// 동일 좌표(반올림 기준)는 제거하고 새 항목을 맨 앞에 둬 최근 5개 유지.
  private static func upsert(
    recents: [PostLocationRecent],
    latitude: Double,
    longitude: Double,
    address: String?
  ) -> [PostLocationRecent] {
    let normalizedLat = (latitude * coordinateRoundingScale).rounded() / coordinateRoundingScale
    let normalizedLon = (longitude * coordinateRoundingScale).rounded() / coordinateRoundingScale
    var filtered = recents.filter { existing in
      let existingLat = (existing.latitude * coordinateRoundingScale).rounded() / coordinateRoundingScale
      let existingLon = (existing.longitude * coordinateRoundingScale).rounded() / coordinateRoundingScale
      return !(existingLat == normalizedLat && existingLon == normalizedLon)
    }
    let entry = PostLocationRecent(
      id: UUID(),
      latitude: latitude,
      longitude: longitude,
      address: address
    )
    filtered.insert(entry, at: 0)
    return Array(filtered.prefix(recentLimit))
  }

  private static func userFacingMessage(for error: Error) -> String {
    if let locationError = error as? LocationClientError {
      switch locationError {
      case .authorizationDenied:
        return "위치 권한이 꺼져 있어요. 설정에서 권한을 켜주세요."
      case .unavailable:
        return "현재 위치를 사용할 수 없어요."
      case .timeout:
        return "위치 확인에 시간이 너무 오래 걸렸어요."
      }
    }
    if let geocoderError = error as? PostLocationGeocoderError {
      switch geocoderError {
      case .notFound:
        return "검색한 주소를 찾지 못했어요."
      case .network:
        return "주소 검색 중 네트워크 오류가 발생했어요."
      }
    }
    return "주소를 확인하지 못했어요. 잠시 후 다시 시도해 주세요."
  }
}

// MARK: - Models

/// 최근 선택 1건. UserDefaults에 직렬화되어 저장된다.
struct PostLocationRecent: Equatable, Identifiable, Sendable, Codable {
  let id: UUID
  let latitude: Double
  let longitude: Double
  let address: String?

  /// 한 줄 표시용 텍스트. 주소가 없으면 좌표를 노출.
  var displayText: String {
    if let address, !address.isEmpty {
      return address
    }
    return String(format: "%.5f, %.5f", latitude, longitude)
  }
}

/// 검색 응답 1건.
struct GeocodedPlace: Equatable, Sendable {
  let latitude: Double
  let longitude: Double
  let address: String?
}

enum PostLocationGeocoderError: Error, Equatable, Sendable {
  case notFound
  case network
}
