//
//  MakeAutoTuneFeature.swift
//  ToneAtelier
//
//  Created by Codex on 5/6/26.
//

import ComposableArchitecture
import Foundation
import OSLog

@Reducer
struct MakeAutoTuneFeature {
  @Dependency(\.makeAutoTuneClient) private var autoTuneClient

  @ObservableState
  struct State: Equatable {
    var isRecommending = false
    var lastSuggestedCategory: MakePhotoCategory?
  }

  enum Action: Equatable, Sendable {
    case delegate(Delegate)
    case recommendButtonTapped(Data)
    case recommendResponse(Result<MakeImageAnalysis, AutoTuneError>)

    enum Delegate: Equatable, Sendable {
      case applyRecommendation(MakePhotoCategory, MakeFilterValues)
    }
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .delegate:
        return .none

      case let .recommendButtonTapped(imageData):
        guard !state.isRecommending else { return .none }
        state.isRecommending = true
        return .run { send in
          do {
            let analysis = try await autoTuneClient.analyze(imageData)
            await send(.recommendResponse(.success(analysis)))
          } catch let error as AutoTuneError {
            await send(.recommendResponse(.failure(error)))
          } catch {
            await send(.recommendResponse(.failure(AutoTuneError(message: error.localizedDescription))))
          }
        }

      case let .recommendResponse(.success(analysis)):
        state.isRecommending = false
        state.lastSuggestedCategory = analysis.category
        return .send(.delegate(.applyRecommendation(analysis.category, analysis.recommendedValues)))

      case let .recommendResponse(.failure(error)):
        state.isRecommending = false
        Logger.makeAutoTune.error("recommend 실패: \(error.message, privacy: .private)")
        return .none
      }
    }
  }
}

struct AutoTuneError: Error, Equatable, Sendable {
  let message: String
}
