//
//  MakeFilterValues.swift
//  ToneAtelier
//
//  Created by Codex on 4/28/26.
//

import Foundation

extension MakeFilterValues {
  nonisolated static let `default` = MakeFilterValues()

  /// spec FilterValuesDTO로 변환. 모든 필드를 항상 채워 보낸다.
  var dto: FilterValuesDTO {
    FilterValuesDTO(
      brightness: brightness,
      exposure: exposure,
      contrast: contrast,
      saturation: saturation,
      sharpness: sharpness,
      blur: blur,
      vignette: vignette,
      noise_reduction: noiseReduction,
      highlights: highlights,
      shadows: shadows,
      temperature: temperature,
      black_point: blackPoint
    )
  }
}
