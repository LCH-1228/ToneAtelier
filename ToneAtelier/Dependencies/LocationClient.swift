//
//  LocationClient.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//

import ComposableArchitecture
import CoreLocation
import Foundation

enum LocationClientError: Error, Equatable, Sendable {
  case authorizationDenied
  case unavailable
  case timeout
}

struct LocationClient {
  /// 권한 상태가 `.notDetermined`이면 시스템 다이얼로그를 띄우고, 사용자 응답이 도착할 때까지 기다린다.
  /// 이미 결정된 상태에서는 즉시 현재 값을 돌려준다.
  var requestAuthorization: @Sendable () async -> CLAuthorizationStatus
  /// 현재 권한 상태를 동기적으로 조회. 시스템 다이얼로그를 띄우지 않는다.
  var currentAuthorizationStatus: @Sendable () async -> CLAuthorizationStatus
  /// 1회성 좌표 조회. authorizedWhenInUse/authorizedAlways가 아니면 즉시 throw.
  var currentLocation: @Sendable () async throws -> CLLocationCoordinate2D
}

extension LocationClient: DependencyKey {
  static let liveValue: LocationClient = LocationClient(
    requestAuthorization: {
      await LiveLocationCenter.shared.requestAuthorization()
    },
    currentAuthorizationStatus: {
      await LiveLocationCenter.shared.currentAuthorizationStatus()
    },
    currentLocation: {
      try await LiveLocationCenter.shared.currentLocation()
    }
  )

  static let testValue = LocationClient(
    requestAuthorization: { .notDetermined },
    currentAuthorizationStatus: { .notDetermined },
    currentLocation: {
      throw LocationClientError.unavailable
    }
  )
}

extension DependencyValues {
  var locationClient: LocationClient {
    get { self[LocationClient.self] }
    set { self[LocationClient.self] = newValue }
  }
}

/// CLLocationManager + delegate를 안전하게 노출하기 위한 싱글턴.
/// delegate 콜백이 main thread로 들어오는 점에 맞춰 MainActor에 격리한다.
@MainActor
final class LiveLocationCenter {
  static let shared = LiveLocationCenter()

  private let bridge = LocationManagerBridge()
  private var authorizationContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
  private var locationContinuation: CheckedContinuation<CLLocationCoordinate2D, Error>?

  init() {
    bridge.onAuthorizationChange = { [weak self] status in
      self?.handleAuthorization(status)
    }
    bridge.onLocationUpdate = { [weak self] result in
      self?.handleLocation(result)
    }
  }

  func requestAuthorization() async -> CLAuthorizationStatus {
    let current = bridge.authorizationStatus
    if current != .notDetermined {
      return current
    }
    // 새 호출 진입 시 이전 continuation이 살아 있으면 즉시 현재 상태로 resume해 leak을 차단.
    // (CheckedContinuation은 1회 resume 미보장이면 런타임 트랩이 뜬다.)
    if let previous = authorizationContinuation {
      authorizationContinuation = nil
      previous.resume(returning: current)
    }
    return await withCheckedContinuation { continuation in
      authorizationContinuation = continuation
      bridge.requestWhenInUseAuthorization()
    }
  }

  func currentAuthorizationStatus() -> CLAuthorizationStatus {
    bridge.authorizationStatus
  }

  func currentLocation() async throws -> CLLocationCoordinate2D {
    let status = bridge.authorizationStatus
    guard status == .authorizedWhenInUse || status == .authorizedAlways else {
      throw LocationClientError.authorizationDenied
    }
    // 진행 중인 좌표 요청이 있으면 새 요청에 자리를 내주고 이전 caller는 cancel로 종료.
    if let previous = locationContinuation {
      locationContinuation = nil
      previous.resume(throwing: CancellationError())
    }
    return try await withCheckedThrowingContinuation { continuation in
      locationContinuation = continuation
      bridge.requestLocation()
    }
  }

  private func handleAuthorization(_ status: CLAuthorizationStatus) {
    // .notDetermined 단계에서도 시스템이 첫 콜백을 보낼 수 있으므로 status 분기를 좁히지 않는다.
    // (예: simulator에서 권한 다이얼로그 없이 즉시 .denied로 떨어지는 케이스)
    if let continuation = authorizationContinuation, status != .notDetermined {
      authorizationContinuation = nil
      continuation.resume(returning: status)
    }
  }

  private func handleLocation(_ result: Result<CLLocationCoordinate2D, Error>) {
    guard let continuation = locationContinuation else { return }
    locationContinuation = nil
    continuation.resume(with: result)
  }
}

/// CLLocationManagerDelegate는 NSObject + 메인 스레드 콜백이 강제되므로,
/// LiveLocationCenter와 같은 MainActor 격리 컨텍스트에서 다룬다.
/// stored callback은 LiveLocationCenter init에서 1회 주입 후 lifetime 동안 고정.
@MainActor
private final class LocationManagerBridge: NSObject, CLLocationManagerDelegate {
  private let manager: CLLocationManager
  var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?
  var onLocationUpdate: ((Result<CLLocationCoordinate2D, Error>) -> Void)?

  override init() {
    self.manager = CLLocationManager()
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
  }

  var authorizationStatus: CLAuthorizationStatus {
    manager.authorizationStatus
  }

  func requestWhenInUseAuthorization() {
    manager.requestWhenInUseAuthorization()
  }

  func requestLocation() {
    manager.requestLocation()
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    onAuthorizationChange?(manager.authorizationStatus)
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    if let coordinate = locations.last?.coordinate {
      onLocationUpdate?(.success(coordinate))
    }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    onLocationUpdate?(.failure(error))
  }
}
