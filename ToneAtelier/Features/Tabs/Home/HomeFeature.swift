//
//  HomeFeature.swift
//  ToneAtelier
//
//  Created by Codex on 4/24/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct HomeFeature {
  @Dependency(\.homeClient) var homeClient

  @ObservableState
  struct State: Equatable {
    var isLoading = false
    var hasLoaded = false
    var errorMessage: String?
    var featuredFilter: HomeFeaturedFilter?
    var categories = HomeCategory.allCases
    var banners: [HomeBanner] = []
    var hotTrends: [HomeTrend] = []
    var focusedTrendID: HomeTrend.ID?
    var featuredAuthor: HomeAuthor?

    var activeBanner: HomeBanner? {
      banners.first
    }

    var hasContent: Bool {
      featuredFilter != nil || !banners.isEmpty || !hotTrends.isEmpty || featuredAuthor != nil
    }
  }

  enum Action: Sendable {
    case categoryTapped(HomeCategory)
    case homeContentResponse(Result<HomeScreenContent, Error>)
    case hotTrendTapped(HomeTrend.ID)
    case reloadButtonTapped
    case task
    case tryFeaturedFilterButtonTapped
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .task:
        guard !state.isLoading, !state.hasLoaded else {
          return .none
        }
        return loadHomeContent(into: &state)

      case .reloadButtonTapped:
        guard !state.isLoading else {
          return .none
        }
        return loadHomeContent(into: &state)

      case let .homeContentResponse(.success(content)):
        state.isLoading = false
        state.hasLoaded = true
        state.errorMessage = nil
        state.featuredFilter = content.featuredFilter
        state.banners = content.banners
        state.hotTrends = content.hotTrends
        state.focusedTrendID = content.hotTrends.dropFirst().first?.id ?? content.hotTrends.first?.id
        state.featuredAuthor = content.featuredAuthor
        return .none

      case let .homeContentResponse(.failure(error)):
        state.isLoading = false
        state.hasLoaded = true
        state.errorMessage = error.userFacingMessage
        return .none

      case let .hotTrendTapped(id):
        state.focusedTrendID = id
        return .none

      case .categoryTapped, .tryFeaturedFilterButtonTapped:
        return .none
      }
    }
  }

  private func loadHomeContent(into state: inout State) -> Effect<Action> {
    state.isLoading = true
    state.errorMessage = nil

    return .run { send in
      await send(
        .homeContentResponse(
          Result {
            try await homeClient.fetchHomeContent()
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
        return "인증 정보가 없어 홈 화면을 불러올 수 없어요."

      case let .invalidSession(statusCode):
        return "세션이 유효하지 않습니다. 다시 로그인해 주세요. (\(statusCode))"

      case let .server(statusCode, message, _):
        if let message, !message.isEmpty {
          return message
        }
        return "서버 응답을 불러오지 못했어요. (\(statusCode))"
      }
    }

    return "홈 화면을 불러오지 못했어요. 잠시 후 다시 시도해 주세요."
  }
}
