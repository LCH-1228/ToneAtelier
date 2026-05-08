//
//  PostCameraModels.swift
//  ToneAtelier
//
//  Pencil node: pJjZX (BS Collapsed), VlQiR (BS Expanded)
//

import Foundation
import SwiftUI

/// 카메라 시트에 노출되는 필터 한 건. 전체/내 생성/구입 탭이 공유하는 통합 표현.
struct PostCameraFilter: Equatable, Identifiable, Sendable {
  let id: String
  let title: String
  /// 작은 thumbnail 용 file URL (보통 files.first). cell 폴백 미리보기에 사용.
  let previewImagePath: String?
  let filterValues: MakeFilterValues
  let isOwned: Bool
  let price: Int?
  /// 활성 칩 dot · cell placeholder 용 컬러. variant-sheet.jsx FILTERS[].swatch 와 동일 의미.
  let swatchColor: Color

  /// summary 에는 filterValues 가 없어 .default 로 채워지는 경우가 많다.
  /// 라이브 프리뷰 렌더는 의미있는 값일 때만 의미있는 결과를 낸다.
  var hasMeaningfulFilterValues: Bool {
    filterValues != .default
  }

  /// detail() 응답으로 채워온 filterValues 로 교체한 사본 반환.
  func with(filterValues newValues: MakeFilterValues) -> PostCameraFilter {
    PostCameraFilter(
      id: id,
      title: title,
      previewImagePath: previewImagePath,
      filterValues: newValues,
      isOwned: isOwned,
      price: price,
      swatchColor: swatchColor
    )
  }
}

enum PostCameraFlashMode: Equatable, Sendable {
  case off
  case on
  case auto
}

enum PostCameraPosition: Equatable, Sendable {
  case back
  case front

  mutating func toggle() {
    self = (self == .back) ? .front : .back
  }
}

enum PostCameraMode: String, Equatable, Sendable, CaseIterable {
  case sloMo
  case video
  case photo
  case portrait

  var displayLabel: String {
    switch self {
    case .sloMo: return "SLO-MO"
    case .video: return "VIDEO"
    case .photo: return "PHOTO"
    case .portrait: return "PORTRAIT"
    }
  }
}

/// preview 탭으로 잡힌 focus + exposure 지점. id 로 fade timer 의 cancel race 를 회피.
struct PostCameraFocus: Equatable, Sendable {
  let id: UUID
  /// (0...1, 0...1) preview-local 정규화 좌표. AVFoundation 의 focusPointOfInterest 와 동일 좌표계.
  let normalizedPoint: CGPoint
}

/// 기기에 따라 제한적으로 지원되는 lens 프리셋. UI 라벨은 iOS 순정 카메라 표기와 동일.
enum PostCameraZoomPreset: String, Equatable, Hashable, Sendable {
  case ultraWide
  case wide
  case telephoto

  var displayLabel: String {
    switch self {
    case .ultraWide: return "0.5x"
    case .wide: return "1x"
    case .telephoto: return "3x"
    }
  }

  var accessibilityLabel: String {
    switch self {
    case .ultraWide: return "초광각"
    case .wide: return "광각"
    case .telephoto: return "망원"
    }
  }
}

enum PostCameraSheetTab: Equatable, Sendable, CaseIterable {
  case all
  case created
  case purchased

  var displayLabel: String {
    switch self {
    case .all: return "전체"
    case .created: return "내 필터"
    case .purchased: return "구입한 필터"
    }
  }
}
