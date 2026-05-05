//
//  VideoDetailFeature.swift
//  ToneAtelier
//
//  Created by Codex on 5/5/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct VideoDetailFeature {
  @Dependency(\.videoClient) private var videoClient
  @Dependency(\.commonClient) private var commonClient

  @ObservableState
  struct State: Equatable {
    var video: VideoResponseDTO
    var streamResponse: StreamUrlResponseDTO?
    var selectedSubtitle: StreamSubtitleDTO?
    var subtitleCues: [SubtitleCue] = []
    var selectedQuality: String?
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var isPlaying = false
    var recommendedVideo: VideoResponseDTO?
    var isStreamLoading = false
    var errorMessage: String?
    var absoluteStreamURL: URL?
    var absoluteQualityURLs: [String: URL] = [:]

    init(video: VideoResponseDTO) {
      self.video = video
      self.duration = video.duration
    }
  }

  enum Action: BindableAction, Sendable {
    case binding(BindingAction<State>)
    case task
    case streamResponse(Result<StreamUrlResponseDTO, Error>)
    case streamURLsResolved(stream: URL?, qualities: [String: URL])
    case recommendedListResponse(Result<VideoListResponseDTO, Error>)
    case subtitleResponse(language: String, Result<Data, Error>)
    case subtitleSelected(StreamSubtitleDTO?)
    case qualitySelected(String?)
    case timeUpdated(current: TimeInterval, duration: TimeInterval)
    case playToggled
    case likeToggled
    case likeResponse(VideoFeature.LikeSnapshot, Result<LikeStatusResponse, Error>)
    case recommendedTapped
    case backTapped
    case delegate(Delegate)

    enum Delegate: Equatable, Sendable {
      case dismiss
      case likeStatusChanged(videoID: String, isLiked: Bool, likeCount: Int)
    }
  }

  var body: some Reducer<State, Action> {
    BindingReducer()
    Reduce { state, action in
      reduce(state: &state, action: action)
    }
  }

  // swiftlint:disable:next function_body_length cyclomatic_complexity
  private func reduce(state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .binding, .delegate:
      return .none

    case .task:
      return loadStreamAndRecommended(state: &state)

    case let .streamResponse(.success(response)):
      state.isStreamLoading = false
      state.streamResponse = response
      let resolveEffect = resolveStreamURLs(response: response)
      let defaultSubtitle = response.subtitles.first(where: { $0.isDefault })
      if let defaultSubtitle {
        state.selectedSubtitle = defaultSubtitle
        return .merge(resolveEffect, downloadSubtitle(defaultSubtitle))
      }
      state.selectedSubtitle = nil
      state.subtitleCues = []
      return resolveEffect

    case let .streamURLsResolved(stream, qualities):
      state.absoluteStreamURL = stream
      state.absoluteQualityURLs = qualities
      return .none

    case let .streamResponse(.failure(error)):
      state.isStreamLoading = false
      state.errorMessage = userFacingMessage(for: error)
      return .none

    case let .recommendedListResponse(.success(response)):
      let candidates = response.data.filter { $0.videoID != state.video.videoID }
      state.recommendedVideo = candidates.randomElement()
      return .none

    case .recommendedListResponse(.failure):
      // 추천은 부가 기능이라 실패해도 메시지 노출하지 않는다.
      return .none

    case let .subtitleResponse(language, .success(data)):
      // 자막 응답이 늦게 도착했더라도 그 사이 사용자가 다른 자막을 선택했으면 무시.
      guard state.selectedSubtitle?.language == language else { return .none }
      let raw = String(data: data, encoding: .utf8) ?? ""
      state.subtitleCues = WebVTTParser.parse(raw)
      return .none

    case .subtitleResponse(_, .failure):
      // 자막 다운로드 실패는 표시만 비활성. 영상 재생은 계속.
      state.subtitleCues = []
      return .none

    case let .subtitleSelected(subtitle):
      state.selectedSubtitle = subtitle
      state.subtitleCues = []
      if let subtitle {
        return downloadSubtitle(subtitle)
      }
      return .cancel(id: "VideoDetailFeature.subtitle")

    case let .qualitySelected(quality):
      state.selectedQuality = quality
      return .none

    case let .timeUpdated(current, duration):
      state.currentTime = current
      if duration > 0 {
        state.duration = duration
      }
      return .none

    case .playToggled:
      state.isPlaying.toggle()
      return .none

    case .likeToggled:
      return handleLikeToggle(state: &state)

    case let .likeResponse(snapshot, .success(response)):
      let confirmed = response.likeStatus
      let delta = (confirmed == snapshot.isLiked) ? 0 : (confirmed ? 1 : -1)
      let adjusted = max(0, snapshot.likeCount + delta)
      state.video = state.video.applyingLike(isLiked: confirmed, likeCount: adjusted)
      return .send(.delegate(.likeStatusChanged(
        videoID: state.video.videoID, isLiked: confirmed, likeCount: adjusted
      )))

    case let .likeResponse(snapshot, .failure):
      state.video = state.video.applyingLike(isLiked: snapshot.isLiked, likeCount: snapshot.likeCount)
      return .none

    case .recommendedTapped:
      guard let next = state.recommendedVideo else { return .none }
      state = State(video: next)
      return .merge(
        .cancel(id: "VideoDetailFeature.subtitle"),
        .cancel(id: "VideoDetailFeature.resolveStream"),
        .send(.task)
      )

    case .backTapped:
      return .send(.delegate(.dismiss))
    }
  }
}

// MARK: - Effect handlers

private extension VideoDetailFeature {
  func loadStreamAndRecommended(state: inout State) -> Effect<Action> {
    state.isStreamLoading = true
    state.errorMessage = nil

    let videoClient = videoClient
    let videoID = state.video.videoID

    return .merge(
      .run { send in
        await send(
          .streamResponse(
            Result {
              try await videoClient.fetchStream(videoID)
            }
          )
        )
      }
      .cancellable(id: "VideoDetailFeature.fetchStream", cancelInFlight: true),
      .run { send in
        await send(
          .recommendedListResponse(
            Result {
              try await videoClient.list(VideoListQuery(next: nil, limit: 10))
            }
          )
        )
      }
      .cancellable(id: "VideoDetailFeature.recommended", cancelInFlight: true)
    )
  }

  func resolveStreamURLs(response: StreamUrlResponseDTO) -> Effect<Action> {
    let videoClient = videoClient
    return .run { send in
      let stream = try? await videoClient.resolveStreamURL(response.streamURL)
      var qualities: [String: URL] = [:]
      for quality in response.qualities {
        if let url = try? await videoClient.resolveStreamURL(quality.url) {
          qualities[quality.quality] = url
        }
      }
      await send(.streamURLsResolved(stream: stream, qualities: qualities))
    }
    .cancellable(id: "VideoDetailFeature.resolveStream", cancelInFlight: true)
  }

  func downloadSubtitle(_ subtitle: StreamSubtitleDTO) -> Effect<Action> {
    let commonClient = commonClient
    let path = subtitle.url
    let language = subtitle.language

    return .run { send in
      await send(
        .subtitleResponse(
          language: language,
          Result {
            try await commonClient.fetchSubtitle(path)
          }
        )
      )
    }
    .cancellable(id: "VideoDetailFeature.subtitle", cancelInFlight: true)
  }

  func handleLikeToggle(state: inout State) -> Effect<Action> {
    let snapshot = VideoFeature.LikeSnapshot(
      isLiked: state.video.isLiked,
      likeCount: state.video.likeCount
    )
    let target = !state.video.isLiked
    state.video = state.video.applyingLike(
      isLiked: target,
      likeCount: max(0, state.video.likeCount + (target ? 1 : -1))
    )
    let videoClient = videoClient
    let videoID = state.video.videoID
    return .run { send in
      await send(
        .likeResponse(
          snapshot,
          Result {
            try await videoClient.setLike(videoID, target)
          }
        )
      )
    }
    .cancellable(id: "VideoDetailFeature.like", cancelInFlight: true)
  }

  func userFacingMessage(for error: Error) -> String {
    if let apiError = error as? APIError {
      switch apiError {
      case let .invalidBaseURL(message),
           let .invalidURL(message),
           let .transport(message),
           let .decoding(message):
        return message
      case .missingAccessToken, .missingRefreshToken:
        return "인증 정보가 없어 영상을 재생할 수 없어요."
      case let .invalidSession(statusCode):
        return "세션이 유효하지 않습니다. 다시 로그인해 주세요. (\(statusCode))"
      case let .server(statusCode, message, _):
        if let message, !message.isEmpty { return message }
        return "스트리밍 응답을 불러오지 못했어요. (\(statusCode))"
      }
    }
    return "영상을 재생할 수 없어요. 잠시 후 다시 시도해 주세요."
  }
}
