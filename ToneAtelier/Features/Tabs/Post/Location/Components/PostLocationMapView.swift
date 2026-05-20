//
//  PostLocationMapView.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//

import MapKit
import SwiftUI

/// 게시글 위치 선택 전용 MKMapView 래퍼.
/// 단일 핀 + 드래그 종료 시 좌표 콜백. SwiftUI Map 대신 사용한 이유는
/// (1) 핀 드래그 종료 시점 정확한 콜백이 필요하고
/// (2) 커스텀 강조 색상을 그대로 쓰기 위함.
struct PostLocationMapView: UIViewRepresentable {
  /// 핀 좌표. nil이면 핀 미노출. 외부에서 update할 때마다 카메라 정렬 + 핀 위치 갱신.
  let coordinate: CLLocationCoordinate2D?
  /// 핀 드래그 종료 시 새 좌표를 부모로 전달.
  let onCoordinateChanged: (CLLocationCoordinate2D) -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(onCoordinateChanged: onCoordinateChanged)
  }

  func makeUIView(context: Context) -> MKMapView {
    let mapView = MKMapView(frame: .zero)
    mapView.delegate = context.coordinator
    mapView.showsUserLocation = false
    mapView.showsCompass = false
    mapView.showsScale = false
    mapView.pointOfInterestFilter = .excludingAll
    mapView.isRotateEnabled = false
    mapView.isPitchEnabled = false

    // 탭 한 번에 핀 이동을 지원. 디자인상 커스텀 인터랙션은 단일 핀이므로
    // gesture 충돌 방지를 위해 single tap만 추가.
    let tapGesture = UITapGestureRecognizer(
      target: context.coordinator,
      action: #selector(Coordinator.handleTap(_:))
    )
    tapGesture.numberOfTapsRequired = 1
    mapView.addGestureRecognizer(tapGesture)

    return mapView
  }

  func updateUIView(_ mapView: MKMapView, context: Context) {
    // 외부 좌표가 갱신되면 기존 핀 제거 후 새 핀 부착 + 카메라 정렬.
    let existingPins = mapView.annotations.compactMap { $0 as? MKPointAnnotation }
    mapView.removeAnnotations(existingPins)

    guard let coordinate else {
      // 좌표가 없으면 서울 중심으로 기본 카메라 정렬.
      let defaultCenter = CLLocationCoordinate2D(
        latitude: PostLocationFallback.seoulCityHall.latitude,
        longitude: PostLocationFallback.seoulCityHall.longitude
      )
      let region = MKCoordinateRegion(
        center: defaultCenter,
        latitudinalMeters: 1500,
        longitudinalMeters: 1500
      )
      mapView.setRegion(region, animated: false)
      return
    }

    let pin = MKPointAnnotation()
    pin.coordinate = coordinate
    mapView.addAnnotation(pin)

    // 카메라가 이미 가까운 영역이면 굳이 재정렬하지 않아 사용자 줌이 깨지지 않게 한다.
    let currentCenter = mapView.region.center
    let distance = MKMapPoint(currentCenter).distance(to: MKMapPoint(coordinate))
    if distance > 200 {
      let region = MKCoordinateRegion(
        center: coordinate,
        latitudinalMeters: 800,
        longitudinalMeters: 800
      )
      mapView.setRegion(region, animated: true)
    }
  }

  final class Coordinator: NSObject, MKMapViewDelegate {
    let onCoordinateChanged: (CLLocationCoordinate2D) -> Void

    init(onCoordinateChanged: @escaping (CLLocationCoordinate2D) -> Void) {
      self.onCoordinateChanged = onCoordinateChanged
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
      guard annotation is MKPointAnnotation else { return nil }
      let identifier = "PostLocationPin"
      let view: MKMarkerAnnotationView
      if let dequeued = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView {
        dequeued.annotation = annotation
        view = dequeued
      } else {
        view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
      }
      view.markerTintColor = UIColor(red: 0x31 / 255.0, green: 0x5C / 255.0, blue: 0x6B / 255.0, alpha: 1)
      view.glyphImage = nil
      view.isDraggable = true
      view.canShowCallout = false
      return view
    }

    func mapView(
      _ mapView: MKMapView,
      annotationView view: MKAnnotationView,
      didChange newState: MKAnnotationView.DragState,
      fromOldState oldState: MKAnnotationView.DragState
    ) {
      if newState == .ending || newState == .canceling {
        view.dragState = .none
        if let coordinate = view.annotation?.coordinate {
          onCoordinateChanged(coordinate)
        }
      }
    }

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
      guard let mapView = gesture.view as? MKMapView else { return }
      let point = gesture.location(in: mapView)
      let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
      onCoordinateChanged(coordinate)
    }
  }
}
