//
//  HomeDetailDesignData.swift
//  ToneAtelier
//
//  Created by Codex on 4/27/26.
//

import SwiftUI

enum HomeDetailDesignData {
  nonisolated static let description = """
  햇살 아래 돋아나는 새싹처럼,
  맑고 투명한 빛을 담은 자연 감성 필터입니다.
  너무 과하지 않게, 부드러운 색감으로 분위기를 살려줍니다.
  새로운 시작, 순수한 감정을 담고 싶을 때 이 필터를 사용해보세요.
  """

  nonisolated static let defaultPresets: [HomeDetailPreset] = [
    HomeDetailPreset(id: "brightness", assetName: AppAsset.HomeDetail.presetBrightness, value: "-3.5"),
    HomeDetailPreset(id: "exposure", assetName: AppAsset.HomeDetail.presetExposure, value: "1.5"),
    HomeDetailPreset(id: "contrast", assetName: AppAsset.HomeDetail.presetContrast, value: "2.5"),
    HomeDetailPreset(id: "saturation", assetName: AppAsset.HomeDetail.presetSaturation, value: "0.1"),
    HomeDetailPreset(id: "sharpness", assetName: AppAsset.HomeDetail.presetSharpness, value: "-4.0"),
    HomeDetailPreset(id: "blur", assetName: AppAsset.HomeDetail.presetBlur, value: "10.5"),
    HomeDetailPreset(id: "vignette", assetName: AppAsset.HomeDetail.presetVignette, value: "-6.0"),
    HomeDetailPreset(id: "noise_reduction", assetName: AppAsset.HomeDetail.presetNoise, value: "7.5"),
    HomeDetailPreset(id: "highlights", assetName: AppAsset.HomeDetail.presetHighlights, value: "0.5"),
    HomeDetailPreset(id: "shadows", assetName: AppAsset.HomeDetail.presetShadows, value: "0.5"),
    HomeDetailPreset(id: "temperature", assetName: AppAsset.HomeDetail.presetTemperature, value: "-1.0"),
    HomeDetailPreset(id: "black_point", assetName: AppAsset.HomeDetail.presetBlackPoint, value: "5.5"),
  ]
}
