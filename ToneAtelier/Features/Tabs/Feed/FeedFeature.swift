//
//  FeedFeature.swift
//  ToneAtelier
//
//  Created by Codex on 4/25/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct FeedFeature {
  @Dependency(\.feedClient) private var feedClient

  @ObservableState
  struct State: Equatable {
    let category: HomeCategory?
    var displayMode: DisplayMode = .block
    var isLoading = false
    var hasLoaded = false
    var errorMessage: String?
    var rankingItems: [FeedRankingItem] = []
    var filterItems: [FeedFilterItem] = []
    var nextCursor = "0"

    var title: String {
      "Feed"
    }

    var hasContent: Bool {
      !rankingItems.isEmpty || !filterItems.isEmpty
    }
  }

  enum DisplayMode: Equatable, Sendable {
    case list
    case block

    var title: String {
      switch self {
      case .list: return "List Mode"
      case .block: return "Block Mode"
      }
    }

    var toggled: Self {
      switch self {
      case .list: return .block
      case .block: return .list
      }
    }
  }

  enum Action: Sendable {
    case displayModeButtonTapped
    case feedContentResponse(Result<FeedScreenContent, Error>)
    case refreshButtonTapped
    case task
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .displayModeButtonTapped:
        state.displayMode = state.displayMode.toggled
        return .none

      case let .feedContentResponse(.success(content)):
        state.isLoading = false
        state.hasLoaded = true
        state.errorMessage = nil
        state.rankingItems = content.rankingItems
        state.filterItems = content.filterItems
        state.nextCursor = content.nextCursor
        return .none

      case let .feedContentResponse(.failure(error)):
        state.isLoading = false
        state.hasLoaded = true
        state.errorMessage = error.userFacingMessage
        return .none

      case .refreshButtonTapped:
        guard !state.isLoading else {
          return .none
        }
        return loadFeedContent(into: &state)

      case .task:
        guard !state.isLoading, !state.hasLoaded else {
          return .none
        }
        return loadFeedContent(into: &state)
      }
    }
  }

  private func loadFeedContent(into state: inout State) -> Effect<Action> {
    state.isLoading = true
    state.errorMessage = nil

    let category = state.category
    let feedClient = feedClient

    return .run { send in
      await send(
        .feedContentResponse(
          Result {
            try await feedClient.fetchFeedContent(category)
          }
        )
      )
    }
  }
}

private extension Error {
  var userFacingMessage: String {
    if let apiError = self as? APIError {
      switch apiError {
      case let .invalidBaseURL(message),
        let .invalidURL(message),
        let .transport(message),
        let .decoding(message):
        return message

      case .missingAccessToken, .missingRefreshToken:
        return "인증 정보가 없어 피드를 불러올 수 없어요."

      case let .invalidSession(statusCode):
        return "세션이 유효하지 않습니다. 다시 로그인해 주세요. (\(statusCode))"

      case let .server(statusCode, message, _):
        if let message, !message.isEmpty {
          return message
        }
        return "서버 응답을 불러오지 못했어요. (\(statusCode))"
      }
    }

    return "피드를 불러오지 못했어요. 잠시 후 다시 시도해 주세요."
  }
}
