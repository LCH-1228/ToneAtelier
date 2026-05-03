//
//  LikedPostsFeature.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//
//  Pencil node: Ah13k (Liked Posts View) + YubvT (Liked Posts Empty View)
//

import ComposableArchitecture
import Foundation

@Reducer
struct LikedPostsFeature {
  @Dependency(\.postClient) private var postClient

  /// FeedFeature 동일 컨벤션: "0"은 더 이상 페이지가 없다는 sentinel.
  private static let endCursor = "0"
  private static let pageLimit = 20

  @ObservableState
  struct State: Equatable {
    var posts: [PostSummaryResponseDTO] = []
    var nextCursor: String = "0"
    var isFirstLoading: Bool = false
    var isPaginating: Bool = false
    var hasLoadedOnce: Bool = false
    var errorMessage: String?

    init() {}
  }

  enum Action: BindableAction, Sendable {
    case binding(BindingAction<State>)
    case task
    case loadFirstPageResponse(Result<PostSummaryPaginationResponseDTO, Error>)
    case loadMoreResponse(Result<PostSummaryPaginationResponseDTO, Error>)
    case lastCardAppeared(postID: String)
    case cardTapped(postID: String)
    case retryTapped
    case backTapped
    case exploreTapped
    case delegate(Delegate)

    enum Delegate: Equatable, Sendable {
      case dismiss
      case postDetailRequested(postID: String)
    }
  }

  var body: some Reducer<State, Action> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .binding:
        return .none

      case .task:
        guard !state.hasLoadedOnce, !state.isFirstLoading else { return .none }
        return loadFirstPage(state: &state)

      case let .loadFirstPageResponse(.success(response)):
        state.isFirstLoading = false
        state.hasLoadedOnce = true
        state.errorMessage = nil
        state.posts = response.data
        state.nextCursor = Self.normalizedCursor(
          previousCursor: nil,
          itemsEmpty: response.data.isEmpty,
          rawNextCursor: response.nextCursor
        )
        return .none

      case let .loadFirstPageResponse(.failure(error)):
        state.isFirstLoading = false
        state.hasLoadedOnce = true
        state.errorMessage = Self.userFacingMessage(for: error)
        return .none

      case let .loadMoreResponse(.success(response)):
        state.isPaginating = false
        let previousCursor = state.nextCursor
        let existingIDs = Set(state.posts.map(\.postID))
        let newItems = response.data.filter { !existingIDs.contains($0.postID) }
        state.posts.append(contentsOf: newItems)
        state.nextCursor = Self.normalizedCursor(
          previousCursor: previousCursor,
          itemsEmpty: newItems.isEmpty,
          rawNextCursor: response.nextCursor
        )
        return .none

      case let .loadMoreResponse(.failure(error)):
        state.isPaginating = false
        state.errorMessage = Self.userFacingMessage(for: error)
        return .none

      case let .lastCardAppeared(postID):
        guard
          !state.isFirstLoading,
          !state.isPaginating,
          state.nextCursor != Self.endCursor,
          state.posts.last?.postID == postID
        else {
          return .none
        }
        state.isPaginating = true

        let postClient = postClient
        let cursor = state.nextCursor
        let nextParameter: String? = cursor.isEmpty ? nil : cursor
        let query = UserPostListQuery(
          category: nil,
          limit: Self.pageLimit,
          next: nextParameter
        )

        return .run { send in
          await send(
            .loadMoreResponse(
              Result {
                try await postClient.likedPosts(query)
              }
            )
          )
        }
        .cancellable(id: "LikedPostsFeature.loadMore", cancelInFlight: true)

      case let .cardTapped(postID):
        return .send(.delegate(.postDetailRequested(postID: postID)))

      case .retryTapped:
        state.hasLoadedOnce = false
        return loadFirstPage(state: &state)

      case .backTapped, .exploreTapped:
        return .send(.delegate(.dismiss))

      case .delegate:
        return .none
      }
    }
  }

  private func loadFirstPage(state: inout State) -> Effect<Action> {
    state.isFirstLoading = true
    state.errorMessage = nil

    let postClient = postClient
    let pageLimit = Self.pageLimit

    return .run { send in
      await send(
        .loadFirstPageResponse(
          Result {
            try await postClient.likedPosts(
              UserPostListQuery(category: nil, limit: pageLimit, next: nil)
            )
          }
        )
      )
    }
    .cancellable(id: "LikedPostsFeature.firstPage", cancelInFlight: true)
  }

  private static func normalizedCursor(
    previousCursor: String?,
    itemsEmpty: Bool,
    rawNextCursor: String?
  ) -> String {
    let raw = rawNextCursor ?? ""
    if raw.isEmpty { return endCursor }
    if raw == endCursor { return endCursor }
    if itemsEmpty, let previousCursor, previousCursor == raw {
      return endCursor
    }
    return raw
  }

  private static func userFacingMessage(for error: Error) -> String {
    if let apiError = error as? APIError {
      switch apiError {
      case let .invalidBaseURL(message),
           let .invalidURL(message),
           let .transport(message),
           let .decoding(message):
        return message

      case .missingAccessToken, .missingRefreshToken:
        return "인증 정보가 없어 좋아한 게시글을 불러올 수 없어요."

      case let .invalidSession(statusCode):
        return "세션이 유효하지 않습니다. 다시 로그인해 주세요. (\(statusCode))"

      case let .server(statusCode, message, _):
        if let message, !message.isEmpty {
          return message
        }
        return "좋아한 게시글을 불러오지 못했어요. (\(statusCode))"
      }
    }
    return "좋아한 게시글을 불러오지 못했어요. 잠시 후 다시 시도해 주세요."
  }
}
