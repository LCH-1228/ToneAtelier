//
//  PostCameraFrameFilter.swift
//  ToneAtelier
//

import CoreImage
import CoreImage.CIFilterBuiltins

/// 매 프레임 CIImage 에 MakeFilterValues 를 적용해 새 CIImage 를 반환한다.
/// MakeImagePipeline 은 imageData(Data) 단위로 동작하므로, 라이브 비디오 스트림에 그대로 쓰기엔
/// 비용이 크다. 동일한 필터 체인을 CIImage in/out 으로 재구성한 streaming 변환만 분리.
enum PostCameraFrameFilter {
  // 12개 파라미터를 순차로 적용하는 한 흐름이라 분기 자체가 본문 — 분리는 의미 없음.
  // swiftlint:disable:next function_body_length
  nonisolated static func apply(_ image: CIImage, values: MakeFilterValues) -> CIImage {
    var current = image

    let colorControls = CIFilter.colorControls()
    colorControls.inputImage = current
    colorControls.brightness = Float(values.brightness)
    colorControls.contrast = Float(values.contrast)
    colorControls.saturation = Float(values.saturation)
    current = colorControls.outputImage ?? current

    if values.exposure != 0 {
      let exposure = CIFilter.exposureAdjust()
      exposure.inputImage = current
      exposure.ev = Float(values.exposure)
      current = exposure.outputImage ?? current
    }

    if values.temperature != 6500 {
      let tempTint = CIFilter.temperatureAndTint()
      tempTint.inputImage = current
      tempTint.neutral = CIVector(x: CGFloat(values.temperature), y: 0)
      tempTint.targetNeutral = CIVector(x: 6500, y: 0)
      current = tempTint.outputImage ?? current
    }

    if values.highlights != 0 || values.shadows != 0 {
      let hsAdjust = CIFilter.highlightShadowAdjust()
      hsAdjust.inputImage = current
      hsAdjust.highlightAmount = Float(1.0 - max(0, values.highlights))
      hsAdjust.shadowAmount = Float(values.shadows)
      current = hsAdjust.outputImage ?? current
    }

    if values.sharpness > 0 {
      let sharpen = CIFilter.sharpenLuminance()
      sharpen.inputImage = current
      sharpen.sharpness = Float(values.sharpness)
      current = sharpen.outputImage ?? current
    }

    if values.blur > 0 {
      let blur = CIFilter.gaussianBlur()
      blur.inputImage = current
      blur.radius = Float(values.blur)
      current = blur.outputImage?.cropped(to: image.extent) ?? current
    }

    if values.vignette != 0 {
      let vignette = CIFilter.vignette()
      vignette.inputImage = current
      vignette.intensity = Float(values.vignette)
      vignette.radius = 1.5
      current = vignette.outputImage ?? current
    }

    if values.noiseReduction > 0 {
      let nr = CIFilter.noiseReduction()
      nr.inputImage = current
      nr.noiseLevel = Float(values.noiseReduction * 0.1)
      nr.sharpness = 0.4
      current = nr.outputImage ?? current
    }

    if values.blackPoint > 0 {
      let bp = CGFloat(values.blackPoint)
      let matrix = CIFilter.colorMatrix()
      matrix.inputImage = current
      matrix.rVector = CIVector(x: 1 - bp, y: 0, z: 0, w: 0)
      matrix.gVector = CIVector(x: 0, y: 1 - bp, z: 0, w: 0)
      matrix.bVector = CIVector(x: 0, y: 0, z: 1 - bp, w: 0)
      matrix.biasVector = CIVector(x: bp, y: bp, z: bp, w: 0)
      current = matrix.outputImage ?? current
    }

    return current
  }
}
