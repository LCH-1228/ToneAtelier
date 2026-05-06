//
//  MakeAutoTuneFeature.swift
//  ToneAtelier
//
//  Created by Codex on 5/6/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct MakeAutoTuneFeature {
  @ObservableState
  struct State: Equatable {
    var isRecommending = false
    var lastSuggestedCategory: MakePhotoCategory?
  }

  enum Action: Equatable, Sendable {
    case delegate(Delegate)
    case recommendButtonTapped
    case recommendResponse(Result<MakePhotoCategory, AutoTuneError>)

    enum Delegate: Equatable, Sendable {
      case applyRecommendation(MakePhotoCategory, MakeFilterValues)
    }
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .delegate:
        return .none

      case .recommendButtonTapped:
        guard !state.isRecommending else { return .none }
        state.isRecommending = true
        return .run { send in
          // 더미 분류 — 다음 sub-branch에서 CoreML/Vision 호출로 교체
          try? await Task.sleep(for: .milliseconds(300))
          await send(.recommendResponse(.success(.defaultBalanced)))
        }

      case let .recommendResponse(.success(category)):
        state.isRecommending = false
        state.lastSuggestedCategory = category
        let preset = MakeFilterPresetCatalog.preset(for: category)
        return .send(.delegate(.applyRecommendation(category, preset)))

      case .recommendResponse(.failure):
        state.isRecommending = false
        return .none
      }
    }
  }
}

struct AutoTuneError: Error, Equatable, Sendable {
  let message: String
}
