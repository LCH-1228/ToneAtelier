//
//  PostCameraFilterValuesInterpolation.swift
//  ToneAtelier
//

import Foundation

extension MakeFilterValues {
  /// 기본값(필터 미적용)에서 self 까지 t in [0, 1] 비율로 선형 보간한 값.
  /// 카메라 필터 강도 슬라이더가 0(원본)~1(완전 적용) 사이 값을 만들 때 사용한다.
  func intensityScaled(_ t: Double) -> MakeFilterValues {
    let clamped = Swift.max(0, Swift.min(1, t))
    let base = MakeFilterValues.default
    var result = MakeFilterValues()
    result.brightness = lerp(base.brightness, brightness, clamped)
    result.exposure = lerp(base.exposure, exposure, clamped)
    result.contrast = lerp(base.contrast, contrast, clamped)
    result.saturation = lerp(base.saturation, saturation, clamped)
    result.sharpness = lerp(base.sharpness, sharpness, clamped)
    result.blur = lerp(base.blur, blur, clamped)
    result.vignette = lerp(base.vignette, vignette, clamped)
    result.noiseReduction = lerp(base.noiseReduction, noiseReduction, clamped)
    result.highlights = lerp(base.highlights, highlights, clamped)
    result.shadows = lerp(base.shadows, shadows, clamped)
    result.temperature = lerp(base.temperature, temperature, clamped)
    result.blackPoint = lerp(base.blackPoint, blackPoint, clamped)
    return result
  }
}

extension MakeFilterValues {
  /// FilterValuesDTO 의 일부 값이 nil 인 경우 기본값으로 채워 MakeFilterValues 로 변환.
  nonisolated init(dto: FilterValuesDTO) {
    let base = MakeFilterValues.default
    self.init(
      brightness: dto.brightness ?? base.brightness,
      exposure: dto.exposure ?? base.exposure,
      contrast: dto.contrast ?? base.contrast,
      saturation: dto.saturation ?? base.saturation,
      sharpness: dto.sharpness ?? base.sharpness,
      blur: dto.blur ?? base.blur,
      vignette: dto.vignette ?? base.vignette,
      noiseReduction: dto.noiseReduction ?? base.noiseReduction,
      highlights: dto.highlights ?? base.highlights,
      shadows: dto.shadows ?? base.shadows,
      temperature: dto.temperature ?? base.temperature,
      blackPoint: dto.blackPoint ?? base.blackPoint
    )
  }
}

private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
  a + (b - a) * t
}
