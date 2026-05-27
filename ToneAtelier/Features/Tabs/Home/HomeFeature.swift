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
  @Dependency(\.videoClient) var videoClient

  @ObservableState
  struct State: Equatable {
    @Presents var alert: AlertState<Action.Alert>?
    var path = StackState<HomePath.State>()
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
    var videoTeaser: VideoResponseDTO?
    var currentUserID: String?

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
    case authorMessageTapped(HomeAuthor)
    case authorProfileTapped(HomeAuthor)
    case bannerIndexChanged(Int)
    case bannerTapped(HomeBanner.ID)
    case bannerWebViewPrepared(Result<HomeBannerWebFeature.State, Error>)
    case categoryTapped(HomeCategory)
    case currentUserResolved(String?)
    case delegate(Delegate)
    case homeContentResponse(Result<HomeScreenContent, Error>)
    case hotTrendScrollPositionChanged(HomeTrend.ID?)
    case hotTrendTapped(HomeTrend.ID)
    case path(StackActionOf<HomePath>)
    case reloadButtonTapped
    case task
    case tryFeaturedFilterButtonTapped
    case videoTeaserResponse(VideoResponseDTO?)
    case videoTeaserTapped

    enum Alert: Equatable, Sendable {}

    enum Delegate: Equatable, Sendable {
      case feedCategorySelected(HomeCategory)
      /// cross-tab chat 진입 — MainTabFeature 가 받아 createRoom + chat 탭 + chatRoom push.
      case messageRequested(userID: String, nick: String, introduction: String?, profileImage: String?)
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

      case let .bannerWebViewPrepared(.success(destinationState)):
        state.path.append(.bannerWeb(destinationState))
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

      case .path(.element(_, .bannerWeb(.delegate(.dismissRequested)))):
        if !state.path.isEmpty { state.path.removeLast() }
        return .none

      case let .path(.element(_, .detail(.delegate(.likeStatusChanged(id, isLiked, likeCount))))):
        state.hotTrends = state.hotTrends.map { trend in
          trend.id == id ? trend.settingLikeCount(likeCount) : trend
        }
        return mirrorLikeToCreatorStores(in: state, id: id, isLiked: isLiked, likeCount: likeCount)

      case let .path(.element(_, .detail(.delegate(.userProfileRequested(userID, nick, introduction, profileImage))))):
        return appendUserProfile(into: &state, userID: userID, nick: nick, introduction: introduction, profileImage: profileImage)

      case let .path(.element(_, .detail(.delegate(.messageRequested(userID, nick, introduction, profileImage))))):
        return .send(
          .delegate(.messageRequested(userID: userID, nick: nick, introduction: introduction, profileImage: profileImage))
        )

      case let .path(.element(_, .userProfile(.delegate(.messageRequested(userID, nick, introduction, profileImage))))):
        return .send(
          .delegate(.messageRequested(userID: userID, nick: nick, introduction: introduction, profileImage: profileImage))
        )

      case let .path(.element(_, .userProfile(.delegate(.storeRequested(userID, headerName))))):
        state.path.append(
          .creatorStore(
            CreatorStoreFeature.State(userID: userID, isOwn: false, headerName: headerName)
          )
        )
        return .none

      case let .path(.element(_, .userProfile(.delegate(.featuredFilterRequested(filter))))):
        state.path.append(.detail(HomeDetailFeature.State(profileFeaturedFilter: filter)))
        return .none

      case let .path(.element(_, .creatorStore(.delegate(.detailRequested(item))))):
        state.path.append(.detail(HomeDetailFeature.State(creatorStoreItem: item)))
        return .none

      case let .authorProfileTapped(author):
        guard !author.id.isEmpty, author.id != state.currentUserID else { return .none }
        return appendUserProfile(
          into: &state,
          userID: author.id,
          nick: author.name,
          introduction: author.subtitle,
          profileImage: author.portraitURL
        )

      case let .authorMessageTapped(author):
        guard !author.id.isEmpty, author.id != state.currentUserID else { return .none }
        return .send(
          .delegate(
            .messageRequested(
              userID: author.id,
              nick: author.name,
              introduction: author.subtitle,
              profileImage: author.portraitURL
            )
          )
        )

      case let .currentUserResolved(userID):
        state.currentUserID = userID
        return .none

      case .path:
        return .none

      case .delegate:
        return .none

      case .task:
        // isLoading 가드를 두면 effect 가 cancel 된 채 isLoading=true 로 stuck 시 .task 재호출이 무시되어
        // "홈 화면을 불러오는 중입니다" 가 영구 표시된다. hasLoaded 만 가드하고 .cancellable 로 중복 방어.
        guard !state.hasLoaded else { return .none }
        return loadHomeContent(into: &state)

      case .reloadButtonTapped:
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
            state.path.append(.detail(HomeDetailFeature.State(trend: trend)))
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
        state.path.append(.detail(HomeDetailFeature.State(featuredFilter: featuredFilter)))
        return .none

      case let .videoTeaserResponse(video):
        state.videoTeaser = video
        return .none

      case .videoTeaserTapped:
        guard state.videoTeaser != nil else { return .none }
        state.path.append(.videoList(VideoFeature.State()))
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
    .forEach(\.path, action: \.path)
  }

  private func loadHomeContent(into state: inout State) -> Effect<Action> {
    state.isLoading = true
    state.errorMessage = nil

    let homeClient = homeClient
    let sessionClient = sessionClient
    let videoClient = videoClient

    return .merge(
      .run { send in
        let snapshot = await sessionClient.snapshot()
        await send(.currentUserResolved(snapshot.currentUserID))
        await send(
          .homeContentResponse(
            Result {
              try await homeClient.fetchHomeContent()
            }
          )
        )
      }
      .cancellable(id: HomeCancelID.content, cancelInFlight: true),
      .run { send in
        let response = try? await videoClient.list(VideoListQuery(next: nil, limit: 1))
        await send(.videoTeaserResponse(response?.data.first))
      }
      .cancellable(id: HomeCancelID.videoTeaser, cancelInFlight: true)
    )
  }

  private func appendUserProfile(
    into state: inout State,
    userID: String,
    nick: String,
    introduction: String?,
    profileImage: String?
  ) -> Effect<Action> {
    state.path.append(
      .userProfile(
        UserProfileFeature.State(
          userID: userID,
          initialNick: nick,
          initialIntroduction: introduction,
          initialProfileImage: profileImage
        )
      )
    )
    return .none
  }

  private func mirrorLikeToCreatorStores(in state: State, id: String, isLiked: Bool, likeCount: Int?) -> Effect<Action> {
    let elementIDs = state.path.ids.filter { elementID in
      if case .creatorStore = state.path[id: elementID] {
        return true
      }
      return false
    }
    guard !elementIDs.isEmpty else { return .none }
    return .merge(
      elementIDs.map { elementID in
        .send(
          .path(.element(id: elementID, action: .creatorStore(.applyExternalLikeChange(id: id, isLiked: isLiked, likeCount: likeCount))))
        )
      }
    )
  }
}

nonisolated private enum HomeCancelID: Hashable, Sendable {
  case content
  case videoTeaser
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
