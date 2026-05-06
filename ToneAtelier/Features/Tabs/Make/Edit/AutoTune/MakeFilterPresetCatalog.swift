//
//  MakeFilterPresetCatalog.swift
//  ToneAtelier
//
//  Created by Codex on 5/6/26.
//

import Foundation

enum MakePhotoCategory: String, CaseIterable, Equatable, Sendable {
  case portrait
  case landscape
  case food
  case night
  case defaultBalanced

  var localizedTitle: String {
    switch self {
    case .portrait:
      return "인물"
    case .landscape:
      return "풍경"
    case .food:
      return "음식"
    case .night:
      return "야경"
    case .defaultBalanced:
      return "기본"
    }
  }
}

enum MakeFilterPresetCatalog {
  static func preset(for category: MakePhotoCategory) -> MakeFilterValues {
    var values = MakeFilterValues()

    switch category {
    case .portrait:
      values.brightness = 0.05
      values.exposure = 0.2
      values.contrast = 1.05
      values.saturation = 0.95
      values.sharpness = 0.2
      values.shadows = 0.15
      values.highlights = -0.1
      values.temperature = 6800
      values.noiseReduction = 0.15

    case .landscape:
      values.contrast = 1.15
      values.saturation = 1.2
      values.sharpness = 0.35
      values.shadows = 0.1
      values.highlights = -0.15
      values.temperature = 6300
      values.vignette = 0.05

    case .food:
      values.brightness = 0.05
      values.contrast = 1.1
      values.saturation = 1.25
      values.sharpness = 0.2
      values.shadows = 0.1
      values.temperature = 7000

    case .night:
      values.exposure = 0.4
      values.contrast = 1.1
      values.shadows = 0.25
      values.highlights = -0.2
      values.noiseReduction = 0.4
      values.temperature = 6000
      values.blackPoint = 0.1

    case .defaultBalanced:
      break
    }

    return values
  }
}
