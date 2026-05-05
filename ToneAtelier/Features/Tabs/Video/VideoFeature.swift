//
//  VideoFeature.swift
//  ToneAtelier
//
//  Created by Codex on 5/5/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct VideoFeature {
  @Dependency(\.videoClient) private var videoClient

  @ObservableState
  struct State: Equatable {
    var listVideos: [VideoResponseDTO] = []
    var nextCursor: String?
    var isFirstLoading: Bool = false
    var isPaginating: Bool = false
    var hasLoadedOnce: Bool = false
    var errorMessage: String?

    var isSearchActive: Bool = false
    var searchQuery: String = ""

    var displayedVideos: [VideoResponseDTO] {
      let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
      guard isSearchActive, !query.isEmpty else { return listVideos }
      return listVideos.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }
  }

  enum Action: BindableAction, Sendable {
    case binding(BindingAction<State>)
    case task
    case lastCardAppeared(videoID: String)
    case cardTapped(videoID: String)
    case cardLikeToggled(videoID: String)
    case loadFirstPageResponse(Result<VideoListResponseDTO, Error>)
    case loadMoreResponse(Result<VideoListResponseDTO, Error>)
    case likeToggleResponse(videoID: String, snapshot: LikeSnapshot, Result<LikeStatusResponse, Error>)
    case searchToggled
    case searchQueryChanged(String)
    case delegate(Delegate)

    enum Delegate: Equatable, Sendable {}
  }

  struct LikeSnapshot: Equatable, Sendable {
    let isLiked: Bool
    let likeCount: Int
  }

  private static let firstPageLimit = 10
  private static let endCursor = ""

  var body: some Reducer<State, Action> {
    BindingReducer()
    Reduce { state, action in
      reduce(state: &state, action: action)
    }
  }

  private func reduce(state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .binding, .delegate:
      return .none

    case .task:
      return handleTask(state: &state)

    case let .lastCardAppeared(videoID):
      return handleLastCardAppeared(state: &state, videoID: videoID)

    case .cardTapped:
      return .none

    case let .cardLikeToggled(videoID):
      return handleCardLikeToggled(state: &state, videoID: videoID)

    case let .loadFirstPageResponse(result):
      return handleFirstPageResponse(state: &state, result: result)

    case let .loadMoreResponse(result):
      return handleLoadMoreResponse(state: &state, result: result)

    case let .likeToggleResponse(videoID, snapshot, .success(response)):
      applyLikeResponse(state: &state, videoID: videoID, snapshot: snapshot, confirmed: response.likeStatus)
      return .none

    case let .likeToggleResponse(videoID, snapshot, .failure):
      revertLikeFailure(state: &state, videoID: videoID, snapshot: snapshot)
      return .none

    case .searchToggled:
      state.isSearchActive.toggle()
      if !state.isSearchActive {
        state.searchQuery = ""
      }
      return .none

    case let .searchQueryChanged(query):
      state.searchQuery = query
      return .none
    }
  }
}

private extension VideoFeature {
  func handleTask(state: inout State) -> Effect<Action> {
    guard !state.hasLoadedOnce, !state.isFirstLoading else { return .none }
    state.isFirstLoading = true
    state.errorMessage = nil

    let videoClient = videoClient
    let query = VideoListQuery(next: nil, limit: Self.firstPageLimit)

    return .run { send in
      await send(
        .loadFirstPageResponse(
          Result {
            try await videoClient.list(query)
          }
        )
      )
    }
    .cancellable(id: "VideoFeature.loadFirst", cancelInFlight: true)
  }

  func handleLastCardAppeared(state: inout State, videoID: String) -> Effect<Action> {
    guard
      !state.isFirstLoading,
      !state.isPaginating,
      let cursor = state.nextCursor,
      cursor != Self.endCursor,
      state.listVideos.last?.videoID == videoID
    else {
      return .none
    }
    state.isPaginating = true

    let videoClient = videoClient
    let query = VideoListQuery(next: cursor, limit: Self.firstPageLimit)

    return .run { send in
      await send(
        .loadMoreResponse(
          Result {
            try await videoClient.list(query)
          }
        )
      )
    }
    .cancellable(id: "VideoFeature.loadMore", cancelInFlight: true)
  }

  func handleFirstPageResponse(
    state: inout State,
    result: Result<VideoListResponseDTO, Error>
  ) -> Effect<Action> {
    state.isFirstLoading = false
    state.hasLoadedOnce = true

    switch result {
    case let .success(response):
      state.errorMessage = nil
      state.listVideos = response.data
      state.nextCursor = Self.normalizedCursor(rawNextCursor: response.nextCursor)

    case let .failure(error):
      state.errorMessage = Self.userFacingMessage(for: error)
    }
    return .none
  }

  func handleLoadMoreResponse(
    state: inout State,
    result: Result<VideoListResponseDTO, Error>
  ) -> Effect<Action> {
    state.isPaginating = false

    switch result {
    case let .success(response):
      state.errorMessage = nil
      let existing = Set(state.listVideos.map(\.videoID))
      let newItems = response.data.filter { !existing.contains($0.videoID) }
      state.listVideos.append(contentsOf: newItems)
      state.nextCursor = Self.normalizedCursor(rawNextCursor: response.nextCursor)

    case let .failure(error):
      state.errorMessage = Self.userFacingMessage(for: error)
    }
    return .none
  }
}

private extension VideoFeature {
  func handleCardLikeToggled(state: inout State, videoID: String) -> Effect<Action> {
    guard let index = state.listVideos.firstIndex(where: { $0.videoID == videoID }) else {
      return .none
    }
    let original = state.listVideos[index]
    let snapshot = LikeSnapshot(isLiked: original.isLiked, likeCount: original.likeCount)
    let target = !original.isLiked
    state.listVideos[index] = original.applyingLike(
      isLiked: target,
      likeCount: max(0, original.likeCount + (target ? 1 : -1))
    )
    return likeRequestEffect(videoID: videoID, snapshot: snapshot, target: target)
  }

  func likeRequestEffect(
    videoID: String,
    snapshot: LikeSnapshot,
    target: Bool
  ) -> Effect<Action> {
    let videoClient = videoClient
    return .run { send in
      await send(
        .likeToggleResponse(
          videoID: videoID,
          snapshot: snapshot,
          Result {
            try await videoClient.setLike(videoID, target)
          }
        )
      )
    }
    .cancellable(id: "VideoFeature.like.\(videoID)", cancelInFlight: true)
  }

  func applyLikeResponse(
    state: inout State,
    videoID: String,
    snapshot: LikeSnapshot,
    confirmed: Bool
  ) {
    let delta = (confirmed == snapshot.isLiked) ? 0 : (confirmed ? 1 : -1)
    let adjusted = max(0, snapshot.likeCount + delta)
    if let index = state.listVideos.firstIndex(where: { $0.videoID == videoID }) {
      state.listVideos[index] = state.listVideos[index]
        .applyingLike(isLiked: confirmed, likeCount: adjusted)
    }
  }

  func revertLikeFailure(state: inout State, videoID: String, snapshot: LikeSnapshot) {
    if let index = state.listVideos.firstIndex(where: { $0.videoID == videoID }) {
      state.listVideos[index] = state.listVideos[index]
        .applyingLike(isLiked: snapshot.isLiked, likeCount: snapshot.likeCount)
    }
  }
}

private extension VideoFeature {
  static func normalizedCursor(rawNextCursor: String?) -> String {
    guard let raw = rawNextCursor, !raw.isEmpty else { return endCursor }
    return raw
  }

  static func userFacingMessage(for error: Error) -> String {
    if let apiError = error as? APIError {
      switch apiError {
      case let .invalidBaseURL(message),
           let .invalidURL(message),
           let .transport(message),
           let .decoding(message):
        return message
      case .missingAccessToken, .missingRefreshToken:
        return "인증 정보가 없어 영상을 불러올 수 없어요."
      case let .invalidSession(statusCode):
        return "세션이 유효하지 않습니다. 다시 로그인해 주세요. (\(statusCode))"
      case let .server(statusCode, message, _):
        if let message, !message.isEmpty { return message }
        return "영상 응답을 불러오지 못했어요. (\(statusCode))"
      }
    }
    return "영상을 불러오지 못했어요. 잠시 후 다시 시도해 주세요."
  }
}

extension VideoResponseDTO {
  func applyingLike(isLiked: Bool, likeCount: Int) -> VideoResponseDTO {
    VideoResponseDTO(
      videoID: videoID,
      fileName: fileName,
      title: title,
      description: description,
      duration: duration,
      thumbnailURL: thumbnailURL,
      availableQualities: availableQualities,
      viewCount: viewCount,
      likeCount: likeCount,
      isLiked: isLiked,
      createdAt: createdAt
    )
  }
}
