//
//  UserPostsFeature.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//
//  Pencil node: hIud2 (User Posts View) + r4DND (Unknown User State)
//

import ComposableArchitecture
import Foundation

@Reducer
struct UserPostsFeature {
  @Dependency(\.postClient) private var postClient
  @Dependency(\.userClient) private var userClient
  @Dependency(\.sessionClient) private var sessionClient

  /// FeedFeature 동일 컨벤션: "0"은 더 이상 페이지가 없다는 sentinel.
  private static let endCursor = "0"
  private static let pageLimit = 20

  @ObservableState
  struct State: Equatable {
    let userID: String
    var headerNickname: String?
    var profile: UserProfile?
    var posts: [PostSummaryResponseDTO] = []
    var selectedCategory: PostCategory?
    var nextCursor: String = "0"
    var isFirstLoading: Bool = false
    var isPaginating: Bool = false
    var hasLoadedOnce: Bool = false
    var isUnknownUser: Bool = false
    var errorMessage: String?
    var currentUserID: String?

    init(userID: String, headerNickname: String? = nil) {
      self.userID = userID
      self.headerNickname = headerNickname
    }

    var isSelf: Bool {
      guard let currentUserID, !currentUserID.isEmpty else { return false }
      return currentUserID == userID
    }
  }

  /// 헤더 표시용 사용자 정보. UserDTO에 직접 의존하지 않고 필요한 필드만 추출.
  struct UserProfile: Equatable, Sendable {
    var nickname: String
    var introduction: String?
    var profileImage: String?
    var hashTags: [String]
  }

  enum Action: BindableAction, Sendable {
    case binding(BindingAction<State>)
    case task
    case sessionLoaded(currentUserID: String?)
    case profileResponse(Result<UserInfoResponseDTO, Error>)
    case loadFirstPageResponse(Result<PostSummaryPaginationResponseDTO, Error>)
    case loadMoreResponse(Result<PostSummaryPaginationResponseDTO, Error>)
    case categoryTapped(PostCategory?)
    case lastCardAppeared(postID: String)
    case cardTapped(postID: String)
    case retryTapped
    case backTapped
    case backToListTapped
    case profileButtonTapped
    case messageButtonTapped
    case delegate(Delegate)

    enum Delegate: Equatable, Sendable {
      case dismiss
      case postDetailRequested(postID: String)
      case userProfileRequested(userID: String, nick: String, introduction: String?, profileImage: String?)
      case messageRequested(userID: String, nick: String, introduction: String?, profileImage: String?)
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
        return loadProfileAndFirstPage(state: &state)

      case let .profileResponse(.success(user)):
        state.profile = UserProfile(
          nickname: user.nick.isEmpty ? "사용자" : user.nick,
          introduction: user.introduction,
          profileImage: user.profileImage,
          hashTags: user.hashTags ?? []
        )
        state.isUnknownUser = false
        return .none

      case let .profileResponse(.failure(error)):
        // 사용자 정보가 없거나 접근 거부된 케이스. unknown user 상태로 진입.
        if Self.isUnknownUserError(error) {
          state.isUnknownUser = true
          state.isFirstLoading = false
          state.hasLoadedOnce = true
          return .cancel(id: "UserPostsFeature.firstPage")
        }
        state.errorMessage = Self.userFacingMessage(for: error)
        return .none

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
        if Self.isUnknownUserError(error) {
          state.isUnknownUser = true
          state.posts = []
          return .none
        }
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

      case let .categoryTapped(category):
        guard state.selectedCategory != category else { return .none }
        state.selectedCategory = category
        state.posts = []
        state.nextCursor = Self.endCursor
        return loadFirstPage(state: &state)

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
        let userID = state.userID
        let cursor = state.nextCursor
        let nextParameter: String? = cursor.isEmpty ? nil : cursor
        let query = UserPostListQuery(
          category: state.selectedCategory?.rawValue,
          limit: Self.pageLimit,
          next: nextParameter
        )

        return .run { send in
          await send(
            .loadMoreResponse(
              Result {
                try await postClient.userPosts(userID, query)
              }
            )
          )
        }
        .cancellable(id: "UserPostsFeature.loadMore", cancelInFlight: true)

      case let .cardTapped(postID):
        return .send(.delegate(.postDetailRequested(postID: postID)))

      case .retryTapped:
        state.isUnknownUser = false
        state.hasLoadedOnce = false
        return loadProfileAndFirstPage(state: &state)

      case .backTapped, .backToListTapped:
        return .send(.delegate(.dismiss))

      case let .sessionLoaded(currentUserID):
        state.currentUserID = currentUserID
        return .none

      case .profileButtonTapped:
        guard !state.isSelf else { return .none }
        let userID = state.userID
        let nick = state.profile?.nickname ?? state.headerNickname ?? ""
        let introduction = state.profile?.introduction
        let profileImage = state.profile?.profileImage
        return .send(
          .delegate(
            .userProfileRequested(userID: userID, nick: nick, introduction: introduction, profileImage: profileImage)
          )
        )

      case .messageButtonTapped:
        guard !state.isSelf else { return .none }
        let userID = state.userID
        let nick = state.profile?.nickname ?? state.headerNickname ?? ""
        let introduction = state.profile?.introduction
        let profileImage = state.profile?.profileImage
        return .send(
          .delegate(
            .messageRequested(userID: userID, nick: nick, introduction: introduction, profileImage: profileImage)
          )
        )

      case .delegate:
        return .none
      }
    }
  }

  /// profile + first page를 병렬로 로드. unknown 판정은 profile 결과를 우선.
  private func loadProfileAndFirstPage(state: inout State) -> Effect<Action> {
    state.isFirstLoading = true
    state.errorMessage = nil
    state.isUnknownUser = false
    state.posts = []
    state.nextCursor = Self.endCursor

    let userClient = userClient
    let postClient = postClient
    let sessionClient = sessionClient
    let userID = state.userID
    let category = state.selectedCategory?.rawValue
    let pageLimit = Self.pageLimit

    return .run { send in
      let snapshot = await sessionClient.snapshot()
      await send(.sessionLoaded(currentUserID: snapshot.currentUserID))

      // userClient/postClient를 병렬 호출.
      async let profileTask = Result { try await userClient.fetchOtherProfile(userID) }
      let query = UserPostListQuery(
        category: category,
        limit: pageLimit,
        next: nil
      )
      async let postsTask = Result { try await postClient.userPosts(userID, query) }

      let profileResult = await profileTask
      await send(.profileResponse(profileResult))

      let postsResult = await postsTask
      await send(.loadFirstPageResponse(postsResult))
    }
    .cancellable(id: "UserPostsFeature.firstPage", cancelInFlight: true)
  }

  /// 카테고리만 변경됐을 때 사용. profile은 재호출하지 않는다.
  private func loadFirstPage(state: inout State) -> Effect<Action> {
    state.isFirstLoading = true
    state.errorMessage = nil

    let postClient = postClient
    let userID = state.userID
    let query = UserPostListQuery(
      category: state.selectedCategory?.rawValue,
      limit: Self.pageLimit,
      next: nil
    )

    return .run { send in
      await send(
        .loadFirstPageResponse(
          Result {
            try await postClient.userPosts(userID, query)
          }
        )
      )
    }
    .cancellable(id: "UserPostsFeature.firstPage", cancelInFlight: true)
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

  /// 404/410/접근 거부에 해당하면 unknown user 상태로 본다.
  private static func isUnknownUserError(_ error: Error) -> Bool {
    if let apiError = error as? APIError {
      switch apiError {
      case let .server(statusCode, _, _):
        return statusCode == 404 || statusCode == 410 || statusCode == 403
      default:
        return false
      }
    }
    return false
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
        return "인증 정보가 없어 게시글을 불러올 수 없어요."

      case let .invalidSession(statusCode):
        return "세션이 유효하지 않습니다. 다시 로그인해 주세요. (\(statusCode))"

      case let .server(statusCode, message, _):
        if let message, !message.isEmpty {
          return message
        }
        return "사용자 게시글을 불러오지 못했어요. (\(statusCode))"
      }
    }
    return "사용자 게시글을 불러오지 못했어요. 잠시 후 다시 시도해 주세요."
  }
}
