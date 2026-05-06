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
    var focusedRankingID: FeedRankingItem.ID?
    var sortOption: FeedSortOption = .popularity
    var filterItems: [FeedFilterItem] = []
    var path = StackState<FeedPath.State>()
    var isLoadingFilterFeed = false
    var filterFeedErrorMessage: String?
    var isLoadingNextPage = false
    var nextPageErrorMessage: String?
    var nextCursor = "0"
    var pendingLikeSnapshots: [FeedFilterItem.ID: FeedLikeSnapshot] = [:]

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

    var resolvedFocusedRankingID: FeedRankingItem.ID? {
      if let focusedRankingID,
         rankingItems.contains(where: { $0.id == focusedRankingID }) {
        return focusedRankingID
      }
      return rankingItems.first?.id
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
    case delegate(Delegate)
    case displayModeButtonTapped
    case filterCardTapped(FeedFilterItem.ID)
    case filterLikeButtonTapped(FeedFilterItem.ID)
    case filterLikeFailed(FeedFilterItem.ID)
    case filterLikeSucceeded(FeedFilterItem.ID, Bool)
    case filterFeedReloadResponse(Result<FeedFilterPage, Error>)
    case filterFeedRetryButtonTapped
    case feedContentResponse(Result<FeedScreenContent, Error>)
    case filterItemAppeared(FeedFilterItem.ID)
    case loadNextPageResponse(Result<FeedFilterPage, Error>)
    case nextPageRetryButtonTapped
    case path(StackActionOf<FeedPath>)
    case rankingCardTapped(FeedRankingItem.ID)
    case rankingScrollPositionChanged(FeedRankingItem.ID?)
    case refreshButtonTapped
    case sortOptionTapped(FeedSortOption)
    case task

    enum Delegate: Equatable, Sendable {
      /// cross-tab chat 진입 — MainTabFeature 가 받아 createRoom + chat 탭 + chatRoom push.
      case messageRequested(userID: String, nick: String, introduction: String?, profileImage: String?)
    }
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .displayModeButtonTapped:
        state.displayMode = state.displayMode.toggled
        return .none

      case let .filterCardTapped(id):
        if let filterItem = state.filterItems.first(where: { $0.id == id }) {
          state.path.append(
            .detail(
              HomeDetailFeature.State(
                id: filterItem.id,
                title: filterItem.title,
                summary: filterItem.description,
                likeCount: filterItem.likeCount,
                imageURL: filterItem.imageURL
              )
            )
          )
        } else if let rankingItem = state.rankingItems.first(where: { $0.id == id }) {
          state.path.append(
            .detail(
              HomeDetailFeature.State(
                id: rankingItem.id,
                title: rankingItem.title,
                summary: nil,
                likeCount: rankingItem.likeCount,
                imageURL: rankingItem.imageURL
              )
            )
          )
        }
        return .none

      case let .filterLikeButtonTapped(id):
        guard let currentStatus = state.likeStatus(for: id),
              state.pendingLikeSnapshots[id] == nil else {
          return .none
        }

        let targetStatus = !currentStatus
        state.pendingLikeSnapshots[id] = state.likeSnapshot(for: id)
        state.applyLikeStatus(targetStatus, to: id)

        let feedClient = feedClient
        return .run { send in
          do {
            let confirmedStatus = try await feedClient.setFilterLike(id, targetStatus)
            await send(.filterLikeSucceeded(id, confirmedStatus))
          } catch {
            await send(.filterLikeFailed(id))
          }
        }

      case let .filterLikeFailed(id):
        guard let snapshot = state.pendingLikeSnapshots.removeValue(forKey: id) else {
          return .none
        }

        state.restoreLikeSnapshot(snapshot, for: id)
        return .none

      case let .filterLikeSucceeded(id, confirmedStatus):
        guard state.pendingLikeSnapshots.removeValue(forKey: id) != nil else {
          return .none
        }
        state.applyLikeStatus(confirmedStatus, to: id)
        return .none

      case let .filterFeedReloadResponse(.success(page)):
        state.isLoadingFilterFeed = false
        state.filterFeedErrorMessage = nil
        state.nextPageErrorMessage = nil
        state.filterItems = page.items
        state.nextCursor = page.nextCursor
        return .none

      case let .filterFeedReloadResponse(.failure(error)):
        state.isLoadingFilterFeed = false
        state.filterFeedErrorMessage = error.userFacingMessage
        return .none

      case .filterFeedRetryButtonTapped:
        return reloadFilterFeed(into: &state)

      case let .feedContentResponse(.success(content)):
        state.isLoading = false
        state.isLoadingFilterFeed = false
        state.hasLoaded = true
        state.errorMessage = nil
        state.filterFeedErrorMessage = nil
        state.nextPageErrorMessage = nil
        state.isLoadingNextPage = false
        state.pendingLikeSnapshots = [:]
        state.rankingItems = content.rankingItems
        state.normalizeFocusedRankingID()
        state.filterItems = content.filterItems
        state.nextCursor = content.nextCursor
        return .none

      case let .feedContentResponse(.failure(error)):
        state.isLoading = false
        state.isLoadingFilterFeed = false
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
        state.filterFeedErrorMessage = nil
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

      case let .rankingCardTapped(id):
        if id == state.resolvedFocusedRankingID {
          if let rankingItem = state.rankingItems.first(where: { $0.id == id }) {
            state.path.append(
              .detail(
                HomeDetailFeature.State(
                  id: rankingItem.id,
                  title: rankingItem.title,
                  summary: nil,
                  likeCount: rankingItem.likeCount,
                  imageURL: rankingItem.imageURL
                )
              )
            )
          }
        } else if state.rankingItems.contains(where: { $0.id == id }) {
          state.focusedRankingID = id
        }
        return .none

      case let .path(.element(_, .detail(.delegate(.likeStatusChanged(id, isLiked, likeCount))))):
        state.applyLikeStatus(isLiked, likeCount: likeCount, to: id)
        return .none

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

      case .delegate:
        return .none

      case .path:
        return .none

      case let .rankingScrollPositionChanged(id):
        guard let id,
              state.rankingItems.contains(where: { $0.id == id }) else {
          return .none
        }
        state.focusedRankingID = id
        return .none

      case .refreshButtonTapped:
        guard !state.isLoading else {
          return .none
        }
        return loadFeedContent(into: &state)

      case let .sortOptionTapped(sortOption):
        guard !state.isLoading, state.sortOption != sortOption else {
          return .none
        }
        state.sortOption = sortOption
        return reloadFilterFeed(into: &state)

      case .task:
        guard !state.isLoading, !state.hasLoaded else {
          return .none
        }
        return loadFeedContent(into: &state)
      }
    }
    .forEach(\.path, action: \.path)
  }

}

// MARK: - Effects

private extension FeedFeature {
  func appendUserProfile(
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

  func loadFeedContent(into state: inout State) -> Effect<Action> {
    state.isLoading = true
    state.errorMessage = nil
    state.filterFeedErrorMessage = nil
    state.nextPageErrorMessage = nil

    let category = state.category
    let sortOption = state.sortOption
    let feedClient = feedClient

    return .run { send in
      await send(
        .feedContentResponse(
          Result {
            try await feedClient.fetchFeedContent(category, sortOption)
          }
        )
      )
    }
  }

  func reloadFilterFeed(into state: inout State) -> Effect<Action> {
    guard !state.isLoading else {
      return .none
    }

    state.isLoadingFilterFeed = true
    state.isLoadingNextPage = false
    state.filterFeedErrorMessage = nil
    state.nextPageErrorMessage = nil
    state.nextCursor = "0"
    state.pendingLikeSnapshots = [:]
    state.filterItems = []

    let category = state.category
    let sortOption = state.sortOption
    let feedClient = feedClient

    return .run { send in
      await send(
        .filterFeedReloadResponse(
          Result {
            try await feedClient.fetchFilterPage(category, sortOption, "")
          }
        )
      )
    }
    .cancellable(id: "FeedFeature.filterPage", cancelInFlight: true)
  }

  func loadNextPage(into state: inout State) -> Effect<Action> {
    guard !state.isLoading,
          !state.isLoadingFilterFeed,
          !state.isLoadingNextPage,
          state.canLoadNextPage else {
      return .none
    }

    state.isLoadingNextPage = true
    state.nextPageErrorMessage = nil

    let category = state.category
    let sortOption = state.sortOption
    let nextCursor = state.nextCursor
    let feedClient = feedClient

    return .run { send in
      await send(
        .loadNextPageResponse(
          Result {
            try await feedClient.fetchFilterPage(category, sortOption, nextCursor)
          }
        )
      )
    }
    .cancellable(id: "FeedFeature.filterPage", cancelInFlight: true)
  }
}

private extension FeedFeature.State {
  mutating func normalizeFocusedRankingID() {
    focusedRankingID = resolvedFocusedRankingID
  }

  func likeStatus(for id: FeedFilterItem.ID) -> Bool? {
    if let filterItem = filterItems.first(where: { $0.id == id }) {
      return filterItem.isLiked
    }
    return rankingItems.first(where: { $0.id == id })?.isLiked
  }

  func likeSnapshot(for id: FeedFilterItem.ID) -> FeedLikeSnapshot {
    FeedLikeSnapshot(
      filterItems: filterItems.filter { $0.id == id },
      rankingItems: rankingItems.filter { $0.id == id }
    )
  }

  mutating func applyLikeStatus(_ status: Bool, to id: FeedFilterItem.ID) {
    applyLikeStatus(status, likeCount: nil, to: id)
  }

  mutating func applyLikeStatus(_ status: Bool, likeCount: Int?, to id: FeedFilterItem.ID) {
    filterItems = filterItems.map { item in
      item.id == id ? item.settingLikeStatus(status, likeCount: likeCount) : item
    }
    rankingItems = rankingItems.map { item in
      item.id == id ? item.settingLikeStatus(status, likeCount: likeCount) : item
    }
  }

  mutating func restoreLikeSnapshot(_ snapshot: FeedLikeSnapshot, for id: FeedFilterItem.ID) {
    var remainingFilterItems = snapshot.filterItems
    filterItems = filterItems.map { item in
      guard item.id == id, !remainingFilterItems.isEmpty else { return item }
      return remainingFilterItems.removeFirst()
    }

    var remainingRankingItems = snapshot.rankingItems
    rankingItems = rankingItems.map { item in
      guard item.id == id, !remainingRankingItems.isEmpty else { return item }
      return remainingRankingItems.removeFirst()
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
