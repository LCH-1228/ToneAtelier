//
//  MakeEditFeature.swift
//  ToneAtelier
//
//  Created by Codex on 4/28/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct MakeEditFeature {
  @ObservableState
  struct State: Equatable {
    let registeredPhoto: MakeFeature.RegisteredPhoto
    let originalFilterValues: MakeFilterValues
    var filterValues: MakeFilterValues
    var selectedParameter = MakeFilterParameter.saturation
    var undoStack: [MakeFilterValues] = []
    var redoStack: [MakeFilterValues] = []
    var editingBaseline: MakeFilterValues?
    var autoTune = MakeAutoTuneFeature.State()

    var canUndo: Bool {
      !undoStack.isEmpty
    }

    var canRedo: Bool {
      !redoStack.isEmpty
    }

    var hasChanges: Bool {
      filterValues != originalFilterValues
    }

    init(
      registeredPhoto: MakeFeature.RegisteredPhoto,
      filterValues: MakeFilterValues = MakeFilterValues()
    ) {
      self.registeredPhoto = registeredPhoto
      self.originalFilterValues = filterValues
      self.filterValues = filterValues
    }
  }

  enum Action: Equatable, Sendable {
    case autoTune(MakeAutoTuneFeature.Action)
    case backButtonTapped
    case delegate(Delegate)
    case filterValueChanged(MakeFilterParameter, Double)
    case filterValueEditingEnded
    case filterValueEditingStarted
    case parameterTapped(MakeFilterParameter)
    case redoButtonTapped
    case saveButtonTapped
    case undoButtonTapped

    enum Delegate: Equatable, Sendable {
      case canceled
      case saved(MakeFilterValues, Data?)
    }
  }

  var body: some Reducer<State, Action> {
    Scope(state: \.autoTune, action: \.autoTune) {
      MakeAutoTuneFeature()
    }
    Reduce { state, action in
      switch action {
      case let .autoTune(.delegate(.applyRecommendation(_, values))):
        state.undoStack.append(state.filterValues)
        state.redoStack.removeAll()
        state.filterValues = values
        state.editingBaseline = nil
        return .none

      case .autoTune:
        return .none

      case .backButtonTapped:
        state.editingBaseline = nil
        state.redoStack.removeAll()
        state.undoStack.removeAll()
        return .send(.delegate(.canceled))

      case .delegate:
        return .none

      case let .filterValueChanged(parameter, value):
        state.filterValues.setValue(value, for: parameter)
        return .none

      case .filterValueEditingEnded:
        guard let editingBaseline = state.editingBaseline else {
          return .none
        }
        state.editingBaseline = nil

        guard editingBaseline != state.filterValues else {
          return .none
        }

        state.undoStack.append(editingBaseline)
        state.redoStack.removeAll()
        return .none

      case .filterValueEditingStarted:
        if state.editingBaseline == nil {
          state.editingBaseline = state.filterValues
        }
        return .none

      case let .parameterTapped(parameter):
        state.selectedParameter = parameter
        return .none

      case .redoButtonTapped:
        guard let nextFilterValues = state.redoStack.popLast() else {
          return .none
        }
        state.undoStack.append(state.filterValues)
        state.filterValues = nextFilterValues
        state.editingBaseline = nil
        return .none

      case .saveButtonTapped:
        state.editingBaseline = nil
        let previewImageData = state.registeredPhoto.previewImageData
        let filterValues = state.filterValues
        return .run { send in
          let filteredData = MakeImagePipeline(imageData: previewImageData)?
            .renderJPEG(filterValues: filterValues)
          await send(.delegate(.saved(filterValues, filteredData)))
        }

      case .undoButtonTapped:
        guard let previousFilterValues = state.undoStack.popLast() else {
          return .none
        }
        state.redoStack.append(state.filterValues)
        state.filterValues = previousFilterValues
        state.editingBaseline = nil
        return .none
      }
    }
  }
}

struct MakeFilterValues: Equatable, Sendable {
  var brightness = 0.0
  var exposure = 0.0
  var contrast = 1.0
  var saturation = 1.0
  var sharpness = 0.0
  var blur = 0.0
  var vignette = 0.0
  var noiseReduction = 0.0
  var highlights = 0.0
  var shadows = 0.0
  var temperature = 6500.0
  var blackPoint = 0.0

  func value(for parameter: MakeFilterParameter) -> Double {
    switch parameter {
    case .brightness:
      return brightness
    case .exposure:
      return exposure
    case .contrast:
      return contrast
    case .saturation:
      return saturation
    case .sharpness:
      return sharpness
    case .blur:
      return blur
    case .vignette:
      return vignette
    case .noiseReduction:
      return noiseReduction
    case .highlights:
      return highlights
    case .shadows:
      return shadows
    case .temperature:
      return temperature
    case .blackPoint:
      return blackPoint
    }
  }

  mutating func setValue(_ value: Double, for parameter: MakeFilterParameter) {
    let clampedValue = parameter.range.clamped(value)

    switch parameter {
    case .brightness:
      brightness = clampedValue
    case .exposure:
      exposure = clampedValue
    case .contrast:
      contrast = clampedValue
    case .saturation:
      saturation = clampedValue
    case .sharpness:
      sharpness = clampedValue
    case .blur:
      blur = clampedValue
    case .vignette:
      vignette = clampedValue
    case .noiseReduction:
      noiseReduction = clampedValue
    case .highlights:
      highlights = clampedValue
    case .shadows:
      shadows = clampedValue
    case .temperature:
      temperature = clampedValue
    case .blackPoint:
      blackPoint = clampedValue
    }
  }
}

enum MakeFilterParameter: CaseIterable, Equatable, Identifiable, Sendable {
  case brightness
  case exposure
  case contrast
  case saturation
  case sharpness
  case blur
  case vignette
  case noiseReduction
  case highlights
  case shadows
  case temperature
  case blackPoint

  var id: Self { self }

  var title: String {
    switch self {
    case .brightness:
      return "BRIGHTNESS"
    case .exposure:
      return "EXPOSURE"
    case .contrast:
      return "CONTRAST"
    case .saturation:
      return "SATURATION"
    case .sharpness:
      return "SHARPNESS"
    case .blur:
      return "BLUR"
    case .vignette:
      return "VIGNETTE"
    case .noiseReduction:
      return "NOISE"
    case .highlights:
      return "HIGHLIGHTS"
    case .shadows:
      return "SHADOWS"
    case .temperature:
      return "TEMPERATURE"
    case .blackPoint:
      return "BLACKPOINT"
    }
  }

  var assetName: String {
    switch self {
    case .brightness:
      return AppAsset.HomeDetail.presetBrightness
    case .exposure:
      return AppAsset.HomeDetail.presetExposure
    case .contrast:
      return AppAsset.HomeDetail.presetContrast
    case .saturation:
      return AppAsset.HomeDetail.presetSaturation
    case .sharpness:
      return AppAsset.HomeDetail.presetSharpness
    case .blur:
      return AppAsset.HomeDetail.presetBlur
    case .vignette:
      return AppAsset.HomeDetail.presetVignette
    case .noiseReduction:
      return AppAsset.HomeDetail.presetNoise
    case .highlights:
      return AppAsset.HomeDetail.presetHighlights
    case .shadows:
      return AppAsset.HomeDetail.presetShadows
    case .temperature:
      return AppAsset.HomeDetail.presetTemperature
    case .blackPoint:
      return AppAsset.HomeDetail.presetBlackPoint
    }
  }

  var range: ClosedRange<Double> {
    switch self {
    case .brightness:
      return -1.0 ... 1.0
    case .exposure:
      return -2.0 ... 2.0
    case .contrast:
      return 0.0 ... 2.0
    case .saturation:
      return 0.0 ... 2.0
    case .sharpness:
      return 0.0 ... 1.0
    case .blur:
      return 0.0 ... 20.0
    case .vignette:
      return -1.0 ... 1.0
    case .noiseReduction:
      return 0.0 ... 1.0
    case .highlights:
      return -1.0 ... 1.0
    case .shadows:
      return -1.0 ... 1.0
    case .temperature:
      return 2500.0 ... 10000.0
    case .blackPoint:
      return 0.0 ... 1.0
    }
  }

  var defaultValue: Double {
    switch self {
    case .contrast, .saturation:
      return 1.0
    case .temperature:
      return 6500.0
    default:
      return 0.0
    }
  }

  var step: Double {
    switch self {
    case .temperature:
      return 50.0
    case .blur:
      return 0.5
    default:
      return 0.01
    }
  }

  func isEdited(value: Double) -> Bool {
    abs(value - defaultValue) > step / 2
  }

  func steppedValue(_ value: Double) -> Double {
    let clampedValue = range.clamped(value)
    guard step > 0 else { return clampedValue }
    let stepped = (clampedValue / step).rounded() * step
    return range.clamped(stepped)
  }

  func displayValue(_ value: Double) -> String {
    switch self {
    case .temperature:
      return "\(Int(value.rounded()))K"
    case .blur:
      return value.formatted(.number.precision(.fractionLength(1)))
    default:
      return value.formatted(.number.precision(.fractionLength(2)))
    }
  }
}

private extension ClosedRange where Bound == Double {
  func clamped(_ value: Double) -> Double {
    Swift.min(Swift.max(value, lowerBound), upperBound)
  }
}
