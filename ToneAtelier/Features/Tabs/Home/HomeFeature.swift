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
  @Dependency(\.commonClient) var commonClient
  @Dependency(\.homeClient) var homeClient
  @Dependency(\.sessionClient) var sessionClient

  @ObservableState
  struct State: Equatable {
    @Presents var alert: AlertState<Action.Alert>?
    var bannerWebView: HomeBannerWebFeature.State?
    var detail: HomeDetailFeature.State?
    var isLoading = false
    var hasLoaded = false
    var errorMessage: String?
    var featuredFilter: HomeFeaturedFilter?
    var categories = HomeCategory.allCases
    var banners: [HomeBanner] = []
    var currentBannerIndex = 0
    var hotTrends: [HomeTrend] = []
    var focusedTrendID: HomeTrend.ID?
    var featuredAuthor: HomeAuthor?

    var activeBanner: HomeBanner? {
      guard banners.indices.contains(currentBannerIndex) else { return banners.first }
      return banners[currentBannerIndex]
    }

    var hasContent: Bool {
      featuredFilter != nil || !banners.isEmpty || !hotTrends.isEmpty || featuredAuthor != nil
    }
  }

  enum Action: Sendable {
    case alert(PresentationAction<Alert>)
    case bannerIndexChanged(Int)
    case bannerTapped(HomeBanner.ID)
    case bannerWebView(HomeBannerWebFeature.Action)
    case bannerWebViewDismissed
    case bannerWebViewPrepared(Result<HomeBannerWebFeature.State, Error>)
    case categoryTapped(HomeCategory)
    case delegate(Delegate)
    case detail(HomeDetailFeature.Action)
    case detailDismissed
    case homeContentResponse(Result<HomeScreenContent, Error>)
    case hotTrendScrollPositionChanged(HomeTrend.ID?)
    case hotTrendTapped(HomeTrend.ID)
    case reloadButtonTapped
    case task
    case tryFeaturedFilterButtonTapped

    enum Alert: Equatable, Sendable {}

    enum Delegate: Equatable, Sendable {
      case feedCategorySelected(HomeCategory)
    }
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .alert:
        return .none

      case let .bannerTapped(id):
        guard let banner = state.banners.first(where: { $0.id == id }),
              let payload = banner.payload,
              payload.type == .webView else {
          return .none
        }

        let commonClient = commonClient
        let sessionClient = sessionClient

        return .run { send in
          do {
            let webViewRequest = try await commonClient.makeWebViewRequest(payload.value)
            let snapshot = await sessionClient.snapshot()
            let destinationState = HomeBannerWebFeature.State(
              title: banner.displayTitle,
              webViewRequest: webViewRequest,
              accessToken: snapshot.accessToken.trimmed
            )
            await send(.bannerWebViewPrepared(.success(destinationState)))
          } catch {
            await send(.bannerWebViewPrepared(.failure(error)))
          }
        }

      case .bannerWebView(.delegate(.dismissRequested)):
        state.bannerWebView = nil
        return .none

      case .bannerWebView:
        return .none

      case .bannerWebViewDismissed:
        state.bannerWebView = nil
        return .none

      case let .detail(.delegate(.likeStatusChanged(id, _, likeCount))):
        state.hotTrends = state.hotTrends.map { trend in
          trend.id == id ? trend.settingLikeCount(likeCount) : trend
        }
        return .none

      case .detail:
        return .none

      case .detailDismissed:
        state.detail = nil
        return .none

      case .delegate:
        return .none

      case let .bannerWebViewPrepared(.success(destinationState)):
        state.bannerWebView = destinationState
        return .none

      case let .bannerWebViewPrepared(.failure(error)):
        state.alert = AlertState {
          TextState("배너를 열 수 없어요")
        } actions: {
          ButtonState(role: .cancel) {
            TextState("확인")
          }
        } message: {
          TextState(error.userFacingMessage)
        }
        return .none

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
        state.currentBannerIndex = 0
        state.hotTrends = content.hotTrends
        state.focusedTrendID = content.hotTrends.first?.id
        state.featuredAuthor = content.featuredAuthor
        return .none

      case let .homeContentResponse(.failure(error)):
        state.isLoading = false
        state.hasLoaded = true
        state.errorMessage = error.userFacingMessage
        return .none

      case let .bannerIndexChanged(index):
        guard state.banners.indices.contains(index) else {
          return .none
        }
        state.currentBannerIndex = index
        return .none

      case let .hotTrendScrollPositionChanged(id):
        state.focusedTrendID = id
        return .none

      case let .hotTrendTapped(id):
        if id == state.focusedTrendID {
          if let trend = state.hotTrends.first(where: { $0.id == id }) {
            state.detail = HomeDetailFeature.State(trend: trend)
          }
        } else {
          state.focusedTrendID = id
        }
        return .none

      case let .categoryTapped(category):
        return .send(.delegate(.feedCategorySelected(category)))

      case .tryFeaturedFilterButtonTapped:
        guard let featuredFilter = state.featuredFilter else {
          return .none
        }
        state.detail = HomeDetailFeature.State(featuredFilter: featuredFilter)
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
    .ifLet(\.bannerWebView, action: \.bannerWebView) {
      HomeBannerWebFeature()
    }
    .ifLet(\.detail, action: \.detail) {
      HomeDetailFeature()
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
