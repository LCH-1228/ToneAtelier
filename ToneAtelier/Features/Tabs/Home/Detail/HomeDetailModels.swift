//
//  HomeDetailModels.swift
//  ToneAtelier
//
//  Created by Codex on 4/27/26.
//

import Foundation

struct HomeDetailExifInfo: Equatable, Sendable {
  let device: String
  let cameraLine: String
  let fileLine: String
  let locationLine: String?

  nonisolated static let placeholder = HomeDetailExifInfo(
    device: "Apple iPhone 16 Pro",
    cameraLine: "와이드 카메라 - 26 mm 𝒇 1.5 ISO 400",
    fileLine: "12MP • 3024 × 4032 • 2.2MB",
    locationLine: "서울 영등포구 선유로 9길 30"
  )
}

struct HomeDetailPreset: Identifiable, Equatable, Sendable {
  let id: String
  let assetName: String
  let value: String
}
