//
//  VideoFeature.swift
//  ToneAtelier
//
//  Created by Codex on 5/5/26.
//

import ComposableArchitecture
import Foundation
import OSLog

@Reducer
struct VideoFeature {
  @Dependency(\.sessionClient) private var sessionClient
  @Dependency(\.videoClient) private var videoClient
  @Dependency(\.videoLocalStore) private var videoLocalStore

  @ObservableState
  struct State: Equatable {
    var listVideos: [VideoResponseDTO] = []
    var nextCursor: String?
    var isFirstLoading: Bool = false
    var isPaginating: Bool = false
    var hasLoadedOnce: Bool = false
    var errorMessage: String?
    var watchProgresses: [String: Double] = [:]
    var currentUserID: String?

    var isSearchActive: Bool = false
    var searchQuery: String = ""

    var detail: VideoDetailFeature.State?

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
    case progressesLoaded([String: Double])
    case userIDLoaded(String?)
    case searchToggled
    case searchQueryChanged(String)
    case detail(VideoDetailFeature.Action)
    case detailDismissed
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
    .ifLet(\.detail, action: \.detail) {
      VideoDetailFeature()
    }
  }

  // swiftlint:disable:next cyclomatic_complexity
  private func reduce(state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .binding, .delegate:
      return .none

    case .task:
      return handleTask(state: &state)

    case let .lastCardAppeared(videoID):
      return handleLastCardAppeared(state: &state, videoID: videoID)

    case let .cardTapped(videoID):
      guard let video = state.listVideos.first(where: { $0.videoID == videoID }) else {
        return .none
      }
      state.detail = VideoDetailFeature.State(video: video, currentUserID: state.currentUserID)
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

    case let .progressesLoaded(map):
      for (videoID, progress) in map {
        state.watchProgresses[videoID] = progress
      }
      return .none

    case let .userIDLoaded(userID):
      state.currentUserID = userID
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

    case let .detail(.delegate(.likeStatusChanged(videoID, isLiked, likeCount))):
      applyDetailLikeSync(state: &state, videoID: videoID, isLiked: isLiked, likeCount: likeCount)
      return .none

    case let .detail(.delegate(.progressUpdated(videoID, progress, currentSeconds, duration))):
      state.watchProgresses[videoID] = progress
      return persistVideoProgressEffect(
        userID: state.currentUserID,
        videoID: videoID,
        progress: progress,
        currentSeconds: currentSeconds,
        duration: duration
      )

    case .detail(.delegate(.dismiss)), .detailDismissed:
      let trailing = trailingPersistEffect(state: &state)
      state.detail = nil
      return trailing

    case .detail:
      return .none
    }
  }
}

// MARK: - Effect handlers

private extension VideoFeature {
  func handleTask(state: inout State) -> Effect<Action> {
    guard !state.hasLoadedOnce, !state.isFirstLoading else { return .none }
    state.isFirstLoading = true
    state.errorMessage = nil

    let sessionClient = sessionClient
    let videoClient = videoClient
    let query = VideoListQuery(next: nil, limit: Self.firstPageLimit)

    // userID는 list 응답 처리 전에 보장돼야 progresses fetch가 비어 나오지 않는다.
    return .run { send in
      let snapshot = await sessionClient.snapshot()
      await send(.userIDLoaded(snapshot.currentUserID))
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
      return loadProgressesEffect(userID: state.currentUserID, videoIDs: response.data.map(\.videoID))

    case let .failure(error):
      state.errorMessage = Self.userFacingMessage(for: error)
      return .none
    }
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
      return loadProgressesEffect(userID: state.currentUserID, videoIDs: newItems.map(\.videoID))

    case let .failure(error):
      state.errorMessage = Self.userFacingMessage(for: error)
      return .none
    }
  }

  func loadProgressesEffect(userID: String?, videoIDs: [String]) -> Effect<Action> {
    guard let userID, !videoIDs.isEmpty else { return .none }
    let videoLocalStore = videoLocalStore
    return .run { send in
      do {
        let map = try await videoLocalStore.progresses(userID, videoIDs)
        await send(.progressesLoaded(map))
      } catch {
        Logger.videoStorage.error(
          "Load progresses failed. error=\(error.localizedDescription, privacy: .public)"
        )
      }
    }
    .cancellable(id: "VideoFeature.loadProgresses", cancelInFlight: false)
  }

  // 부모 cancellable scope에서 발사 — detail unmount(ifLet cancel)와 무관해 disk write가 보장된다.
  func persistVideoProgressEffect(
    userID: String?,
    videoID: String,
    progress: Double,
    currentSeconds: Double,
    duration: Double
  ) -> Effect<Action> {
    guard let userID, duration > 0 else { return .none }
    let videoLocalStore = videoLocalStore
    return .run { _ in
      do {
        try await videoLocalStore.upsert(userID, videoID, progress, currentSeconds, duration, Date())
      } catch {
        Logger.videoStorage.error(
          "Persist video progress failed. error=\(error.localizedDescription, privacy: .public)"
        )
      }
    }
    .cancellable(id: "VideoFeature.persistVideo.\(videoID)", cancelInFlight: false)
  }

  func trailingPersistEffect(state: inout State) -> Effect<Action> {
    guard let detail = state.detail else { return .none }
    let videoID = detail.video.videoID
    let currentSeconds = detail.currentTime
    let duration = detail.duration
    guard duration > 0 else { return .none }
    var progress = currentSeconds / duration
    if progress >= 0.95 { progress = 1.0 }
    progress = max(0, min(1, progress))
    state.watchProgresses[videoID] = progress
    return persistVideoProgressEffect(
      userID: state.currentUserID,
      videoID: videoID,
      progress: progress,
      currentSeconds: currentSeconds,
      duration: duration
    )
  }
}

// MARK: - Like handling

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

  func applyDetailLikeSync(
    state: inout State,
    videoID: String,
    isLiked: Bool,
    likeCount: Int
  ) {
    if let index = state.listVideos.firstIndex(where: { $0.videoID == videoID }) {
      state.listVideos[index] = state.listVideos[index]
        .applyingLike(isLiked: isLiked, likeCount: likeCount)
    }
  }
}

// MARK: - Helpers

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
