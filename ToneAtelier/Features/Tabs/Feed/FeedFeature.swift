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
    var isLoadingNextPage = false
    var nextPageErrorMessage: String?
    var nextCursor = "0"
    var pendingLikeSnapshots: [FeedFilterItem.ID: FeedFilterItem] = [:]

    var title: String {
      "Feed"
    }

    var hasContent: Bool {
      !rankingItems.isEmpty || !filterItems.isEmpty
    }

    var canLoadNextPage: Bool {
      hasLoaded && !filterItems.isEmpty && nextCursor != "0"
    }

    var likingFilterIDs: Set<FeedFilterItem.ID> {
      Set(pendingLikeSnapshots.keys)
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
    case filterLikeButtonTapped(FeedFilterItem.ID)
    case filterLikeFailed(FeedFilterItem.ID)
    case filterLikeSucceeded(FeedFilterItem.ID)
    case feedContentResponse(Result<FeedScreenContent, Error>)
    case filterItemAppeared(FeedFilterItem.ID)
    case loadNextPageResponse(Result<FeedFilterPage, Error>)
    case nextPageRetryButtonTapped
    case refreshButtonTapped
    case task
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .displayModeButtonTapped:
        state.displayMode = state.displayMode.toggled
        return .none

      case let .filterLikeButtonTapped(id):
        guard let index = state.filterItems.firstIndex(where: { $0.id == id }),
              state.pendingLikeSnapshots[id] == nil else {
          return .none
        }

        let previousItem = state.filterItems[index]
        let targetStatus = !previousItem.isLiked
        state.pendingLikeSnapshots[id] = previousItem
        state.filterItems[index] = previousItem.settingLikeStatus(targetStatus)

        let feedClient = feedClient
        return .run { send in
          do {
            _ = try await feedClient.setFilterLike(id, targetStatus)
            await send(.filterLikeSucceeded(id))
          } catch {
            await send(.filterLikeFailed(id))
          }
        }

      case let .filterLikeFailed(id):
        guard let previousItem = state.pendingLikeSnapshots.removeValue(forKey: id),
              let index = state.filterItems.firstIndex(where: { $0.id == id }) else {
          return .none
        }

        state.filterItems[index] = previousItem
        return .none

      case let .filterLikeSucceeded(id):
        state.pendingLikeSnapshots[id] = nil
        return .none

      case let .feedContentResponse(.success(content)):
        state.isLoading = false
        state.hasLoaded = true
        state.errorMessage = nil
        state.nextPageErrorMessage = nil
        state.isLoadingNextPage = false
        state.pendingLikeSnapshots = [:]
        state.rankingItems = content.rankingItems
        state.filterItems = content.filterItems
        state.nextCursor = content.nextCursor
        return .none

      case let .feedContentResponse(.failure(error)):
        state.isLoading = false
        state.isLoadingNextPage = false
        state.hasLoaded = true
        state.errorMessage = error.userFacingMessage
        return .none

      case let .filterItemAppeared(id):
        guard state.filterItems.last?.id == id else {
          return .none
        }
        guard state.nextPageErrorMessage == nil else {
          return .none
        }
        return loadNextPage(into: &state)

      case let .loadNextPageResponse(.success(page)):
        state.isLoadingNextPage = false
        state.nextPageErrorMessage = nil

        let previousCursor = state.nextCursor
        let existingIDs = Set(state.filterItems.map(\.id))
        let newItems = page.items.filter { !existingIDs.contains($0.id) }

        state.nextCursor = newItems.isEmpty && page.nextCursor == previousCursor ? "0" : page.nextCursor
        state.filterItems.append(contentsOf: newItems)
        return .none

      case let .loadNextPageResponse(.failure(error)):
        state.isLoadingNextPage = false
        state.nextPageErrorMessage = error.userFacingMessage
        return .none

      case .nextPageRetryButtonTapped:
        return loadNextPage(into: &state)

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
    state.nextPageErrorMessage = nil

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

  private func loadNextPage(into state: inout State) -> Effect<Action> {
    guard !state.isLoading,
          !state.isLoadingNextPage,
          state.canLoadNextPage else {
      return .none
    }

    state.isLoadingNextPage = true
    state.nextPageErrorMessage = nil

    let category = state.category
    let nextCursor = state.nextCursor
    let feedClient = feedClient

    return .run { send in
      await send(
        .loadNextPageResponse(
          Result {
            try await feedClient.fetchFilterPage(category, nextCursor)
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
