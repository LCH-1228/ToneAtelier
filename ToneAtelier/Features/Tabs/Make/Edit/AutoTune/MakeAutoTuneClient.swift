//
//  MakeAutoTuneClient.swift
//  ToneAtelier
//
//  Created by Codex on 5/6/26.
//

import ComposableArchitecture
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import OSLog
import Vision

struct MakeImageAnalysis: Equatable, Sendable {
  let category: MakePhotoCategory
  let recommendedValues: MakeFilterValues
}

struct MakeAutoTuneClient: Sendable {
  var analyze: @Sendable (_ imageData: Data) async throws -> MakeImageAnalysis
}

extension MakeAutoTuneClient: DependencyKey {
  static let liveValue = MakeAutoTuneClient(
    analyze: { imageData in
      try await MakeAutoTuneClassifier.analyze(imageData: imageData)
    }
  )

  static let testValue = MakeAutoTuneClient(
    analyze: { _ in throw AutoTuneError(message: "MakeAutoTuneClient.analyze testValue") }
  )
}

extension DependencyValues {
  var makeAutoTuneClient: MakeAutoTuneClient {
    get { self[MakeAutoTuneClient.self] }
    set { self[MakeAutoTuneClient.self] = newValue }
  }
}

private enum MakeAutoTuneClassifier {
  // 휘도가 이 값 미만이면 분류 모델을 거치지 않고 night 로 단정 — VNClassifyImageRequest 가 night 라벨을 직접 주지 않기 때문
  private static let nightLuminanceCutoff = 0.18

  static func analyze(imageData: Data) async throws -> MakeImageAnalysis {
    try await Task.detached(priority: .userInitiated) {
      guard let ciImage = CIImage(data: imageData) else {
        throw AutoTuneError(message: "invalid image data")
      }

      let recommendedValues = recommendValues(image: ciImage)
      let category = resolveCategory(image: ciImage)
      Logger.makeAutoTune.notice(
        "category=\(category.rawValue, privacy: .public)"
      )
      return MakeImageAnalysis(category: category, recommendedValues: recommendedValues)
    }.value
  }

  // MARK: - Slider recommendation via Apple autoAdjustmentFilters

  private static func recommendValues(image: CIImage) -> MakeFilterValues {
    let options: [CIImageAutoAdjustmentOption: Any] = [
      .enhance: true,
      .redEye: false
    ]
    let filters = image.autoAdjustmentFilters(options: options)
    var values = MakeFilterValues()
    for filter in filters {
      apply(filter: filter, to: &values)
    }
    return values
  }

  private static func apply(filter: CIFilter, to values: inout MakeFilterValues) {
    switch filter.name {
    case "CIVibrance":
      // CIVibrance.inputAmount: [-1, 1], default 0 (양수=채도 ↑)
      // 우리 saturation: [0, 2], default 1.0
      if let amount = filter.value(forKey: "inputAmount") as? Double {
        values.setValue(1.0 + amount, for: .saturation)
      }

    case "CIHighlightShadowAdjust":
      // inputHighlightAmount: [0.3, 1.0], default 1.0 (1.0 = 변화 없음, < 1.0 = highlight darken)
      // 우리 highlights: [-1, 1], default 0 (음수 = darken)
      if let highlight = filter.value(forKey: "inputHighlightAmount") as? Double {
        values.setValue(highlight - 1.0, for: .highlights)
      }
      // inputShadowAmount: [-1, 1], default 0 — 우리 shadows 와 동일 의미
      if let shadow = filter.value(forKey: "inputShadowAmount") as? Double {
        values.setValue(shadow, for: .shadows)
      }

    case "CIToneCurve":
      applyToneCurve(filter: filter, to: &values)

    default:
      break
    }
  }

  private static func applyToneCurve(filter: CIFilter, to values: inout MakeFilterValues) {
    let points: [CIVector] = (0...4).compactMap { index in
      filter.value(forKey: "inputPoint\(index)") as? CIVector
    }
    guard points.count == 5 else { return }
    let y0 = Double(points[0].y)
    let y2 = Double(points[2].y)
    let y4 = Double(points[4].y)

    // mid-tone shift → exposure (default y2=0.5 → 0)
    values.setValue((y2 - 0.5) * 4.0, for: .exposure)

    // 휘도 spread → contrast (default y4-y0=1.0)
    values.setValue(y4 - y0, for: .contrast)

    // black point lift (default y0=0)
    values.setValue(y0, for: .blackPoint)
  }

  // MARK: - Category (메타데이터 보존용)

  private static func resolveCategory(image: CIImage) -> MakePhotoCategory {
    if computeAverageLuminance(image: image) < nightLuminanceCutoff {
      return .night
    }
    return classify(image: image)
  }

  private static func computeAverageLuminance(image: CIImage) -> Double {
    let extent = image.extent
    guard !extent.isEmpty else { return 0.5 }

    let filter = CIFilter.areaAverage()
    filter.inputImage = image
    filter.extent = extent
    guard let output = filter.outputImage else { return 0.5 }

    var bitmap = [UInt8](repeating: 0, count: 4)
    let context = CIContext(options: nil)
    context.render(
      output,
      toBitmap: &bitmap,
      rowBytes: 4,
      bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
      format: .RGBA8,
      colorSpace: CGColorSpaceCreateDeviceRGB()
    )

    let red = Double(bitmap[0]) / 255.0
    let green = Double(bitmap[1]) / 255.0
    let blue = Double(bitmap[2]) / 255.0
    return 0.299 * red + 0.587 * green + 0.114 * blue
  }

  private static func classify(image: CIImage) -> MakePhotoCategory {
    let request = VNClassifyImageRequest()
    let handler = VNImageRequestHandler(ciImage: image, options: [:])

    do {
      try handler.perform([request])
    } catch {
      Logger.makeAutoTune.error(
        "VNClassifyImageRequest 실패: \(error.localizedDescription, privacy: .private)"
      )
      return .defaultBalanced
    }

    let observations = request.results ?? []
    let identifiers = observations
      .filter { $0.confidence > 0.1 }
      .prefix(15)
      .map { $0.identifier.lowercased() }
    return mapToCategory(identifiers: identifiers)
  }

  private static let categoryKeywords: [(MakePhotoCategory, [String])] = [
    (.portrait, ["person", "people", "face", "portrait", "selfie", "child", "baby"]),
    (.food, ["food", "meal", "dish", "drink", "pizza", "burger", "dessert", "bread", "fruit", "vegetable"]),
    (.landscape, [
      "mountain", "outdoor", "sky", "tree", "ocean", "beach",
      "lake", "valley", "forest", "cloud", "sea", "field"
    ])
  ]

  private static func mapToCategory(identifiers: [String]) -> MakePhotoCategory {
    for (category, keywords) in categoryKeywords where identifiers.contains(where: { identifier in
      keywords.contains(where: identifier.contains)
    }) {
      return category
    }
    return .defaultBalanced
  }
}
