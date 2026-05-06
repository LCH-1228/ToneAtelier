//
//  ProfileFeature.swift
//  ToneAtelier
//
//  Created by Codex on 5/1/26.
//

import ComposableArchitecture
import Foundation

// TODO: 응답 추출 helper는 후속 브랜치에서 전용 Decodable DTO로 대체.
// TODO: 통계 카운트는 임시(필터 수·좋아하는 필터 수)이며 후속 브랜치에서 정확화.

@Reducer
// swiftlint:disable:next type_body_length
struct ProfileFeature {
  @Dependency(\.userClient) var userClient
  @Dependency(\.filterClient) var filterClient
  @Dependency(\.sessionClient) var sessionClient

  @ObservableState
  struct State: Equatable {
    var summary: ProfileSummary = .placeholder
    var featuredFilter: FeaturedFilter? = .placeholder
    var likedFilters: [LikedFilter] = LikedFilter.placeholders
    var currentUserID: String?
    var isLoading = false
    var hasLoaded = false
    var errorMessage: String?
    var path = StackState<ProfilePath.State>()
  }

  struct LoadedProfile: Equatable, Sendable {
    var summary: ProfileSummary
    var featuredFilter: FeaturedFilter?
    var likedFilters: [LikedFilter]
    var currentUserID: String?
  }

  enum Action: BindableAction, Sendable {
    case binding(BindingAction<State>)
    case task
    case retryButtonTapped
    case profileLoadResponse(Result<LoadedProfile, Error>)
    case settingsButtonTapped
    case editProfileButtonTapped
    case creatorStoreButtonTapped
    case featuredFilterTapped
    case likedFilterTapped(LikedFilter.ID)
    case viewAllLikesTapped
    case userPostsTapped
    case likedPostsTapped
    case path(StackActionOf<ProfilePath>)
    case delegate(Delegate)

    enum Delegate: Equatable, Sendable {
      case makeFilterRequested
      case logoutRequested
      /// cross-tab chat 진입 — MainTabFeature 가 받아 createRoom + chat 탭 + chatRoom push.
      case messageRequested(userID: String, nick: String, introduction: String?, profileImage: String?)
    }
  }

  var body: some Reducer<State, Action> {
    BindingReducer()
    core
      .forEach(\.path, action: \.path)
  }

  /// 메인 reducer 로직. body 분리로 type-check 한도 회피.
  @ReducerBuilder<State, Action>
  // swiftlint:disable:next function_body_length
  private var core: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .binding:
        return .none

      case .task:
        guard !state.isLoading, !state.hasLoaded else { return .none }
        return loadProfile(into: &state)

      case .retryButtonTapped:
        guard !state.isLoading else { return .none }
        return loadProfile(into: &state)

      case let .profileLoadResponse(.success(loaded)):
        state.isLoading = false
        state.hasLoaded = true
        state.errorMessage = nil
        state.summary = loaded.summary
        state.featuredFilter = loaded.featuredFilter
        state.likedFilters = loaded.likedFilters
        state.currentUserID = loaded.currentUserID
        return .none

      case let .profileLoadResponse(.failure(error)):
        state.isLoading = false
        state.hasLoaded = true
        state.errorMessage = error.userFacingMessage
        return .none

      case .settingsButtonTapped:
        state.path.append(.preference(PreferenceFeature.State(summary: state.summary)))
        return .none

      case .editProfileButtonTapped:
        state.path.append(
          .editProfile(
            ProfileEditFeature.State(
              nickname: state.summary.nickname,
              email: state.summary.email,
              name: state.summary.name,
              phoneNum: state.summary.phoneNum ?? "",
              introduction: state.summary.bio,
              hashTags: state.summary.hashTags,
              avatarURL: state.summary.avatarURL
            )
          )
        )
        return .none

      case .featuredFilterTapped:
        guard let filter = state.featuredFilter else { return .none }
        state.path.append(.detail(HomeDetailFeature.State(profileFeaturedFilter: filter)))
        return .none

      case let .likedFilterTapped(id):
        guard let filter = state.likedFilters.first(where: { $0.id == id }) else { return .none }
        state.path.append(.detail(HomeDetailFeature.State(likedFilter: filter)))
        return .none

      case .viewAllLikesTapped:
        state.path.append(.likedFiltersList(LikedFiltersFeature.State()))
        return .none

      case .creatorStoreButtonTapped:
        guard let userID = state.currentUserID, !userID.isEmpty else {
          return .none
        }
        state.path.append(
          .creatorStore(
            CreatorStoreFeature.State(
              userID: userID,
              isOwn: true,
              headerName: state.summary.nickname
            )
          )
        )
        return .none

      case .userPostsTapped:
        guard let userID = state.currentUserID, !userID.isEmpty else {
          return .none
        }
        state.path.append(
          .userPostsList(
            UserPostsFeature.State(
              userID: userID,
              headerNickname: state.summary.nickname
            )
          )
        )
        return .none

      case .likedPostsTapped:
        state.path.append(.likedPostsList(LikedPostsFeature.State()))
        return .none

      case let .path(.element(_, .detail(.delegate(.likeStatusChanged(id, isLiked, likeCount))))):
        applyLikeChange(id: id, isLiked: isLiked, likeCount: likeCount, into: &state)
        return .none

      case let .path(.element(_, .likedFiltersList(.delegate(.likeStatusChanged(id, likeCount, isLiked))))):
        applyLikeChange(id: id, isLiked: isLiked, likeCount: likeCount, into: &state)
        return .none

      case let .path(.element(_, .creatorStore(.delegate(.likeStatusChanged(id, likeCount, isLiked))))):
        applyLikeChange(id: id, isLiked: isLiked, likeCount: likeCount, into: &state)
        return .none

      case let .path(.element(_, .creatorStore(.delegate(.detailRequested(item))))):
        state.path.append(.detail(HomeDetailFeature.State(creatorStoreItem: item)))
        return .none

      case let .path(.element(id, .creatorStore(.delegate(.makeFilterRequested)))):
        state.path.pop(from: id)
        state.path.append(.makeView(MakeFeature.State()))
        return .none

      case .path(.element(_, .makeView(.delegate(.filterCreated)))):
        // 새 필터 생성 후 makeView 를 pop. creatorStore 는 makeFilterRequested 시 이미 pop 됐고,
        // 다음 진입 시 새 State 로 만들어지므로 캐시 무효화 불필요.
        if !state.path.isEmpty { state.path.removeLast() }
        return .none

      case let .path(.element(_, .userPostsList(.delegate(.postDetailRequested(postID))))):
        state.path.append(.postDetail(PostDetailFeature.State(postID: postID)))
        return .none

      case let .path(.element(_, .userPostsList(.delegate(.userProfileRequested(userID, nick, introduction, profileImage))))):
        return appendUserProfile(into: &state, userID: userID, nick: nick, introduction: introduction, profileImage: profileImage)

      case let .path(.element(_, .userPostsList(.delegate(.messageRequested(userID, nick, introduction, profileImage))))):
        return forwardMessageRequest(userID: userID, nick: nick, introduction: introduction, profileImage: profileImage)

      case let .path(.element(_, .likedPostsList(.delegate(.postDetailRequested(postID))))):
        state.path.append(.postDetail(PostDetailFeature.State(postID: postID)))
        return .none

      case let .path(.element(_, .detail(.delegate(.userProfileRequested(userID, nick, introduction, profileImage))))):
        return appendUserProfile(into: &state, userID: userID, nick: nick, introduction: introduction, profileImage: profileImage)

      case let .path(.element(_, .detail(.delegate(.messageRequested(userID, nick, introduction, profileImage))))):
        return forwardMessageRequest(userID: userID, nick: nick, introduction: introduction, profileImage: profileImage)

      case let .path(.element(_, .userProfile(.delegate(.messageRequested(userID, nick, introduction, profileImage))))):
        return forwardMessageRequest(userID: userID, nick: nick, introduction: introduction, profileImage: profileImage)

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


      case let .path(.element(id, .userPostsList(.delegate(.dismiss)))):
        state.path.pop(from: id)
        return .none

      case let .path(.element(id, .likedPostsList(.delegate(.dismiss)))):
        state.path.pop(from: id)
        return .none

      case let .path(.element(id, .postDetail(.delegate(.dismiss)))):
        state.path.pop(from: id)
        return .none

      case let .path(.element(id, .postDetail(.delegate(.userPostsRequested(userID))))):
        state.path.pop(from: id)
        state.path.append(.userPostsList(UserPostsFeature.State(userID: userID)))
        return .none

      case let .path(.element(id, .editProfile(.delegate(.profileUpdated(saved))))):
        state.summary.nickname = saved.nickname
        state.summary.bio = saved.introduction
        state.summary.phoneNum = saved.phoneNum.isEmpty ? nil : saved.phoneNum
        state.summary.hashTags = saved.hashTags
        state.summary.avatarURL = saved.avatarURL
        state.path.pop(from: id)
        return .none

      case let .path(.element(id, .editProfile(.delegate(.dismissRequested)))):
        state.path.pop(from: id)
        return .none

      case .path(.element(_, .preference(.delegate(.logoutRequested)))):
        state.path.removeAll()
        return .send(.delegate(.logoutRequested))

      case .path:
        return .none

      case .delegate:
        return .none
      }
    }
  }
}

// MARK: - Helpers / Effects

private extension ProfileFeature {
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

  func forwardMessageRequest(
    userID: String,
    nick: String,
    introduction: String?,
    profileImage: String?
  ) -> Effect<Action> {
    .send(
      .delegate(
        .messageRequested(userID: userID, nick: nick, introduction: introduction, profileImage: profileImage)
      )
    )
  }

  func applyLikeChange(id: String, isLiked: Bool, likeCount: Int?, into state: inout State) {
    if isLiked {
      state.likedFilters = state.likedFilters.map { liked in
        liked.id == id ? liked.settingLike(isLiked, likeCount: likeCount) : liked
      }
    } else {
      state.likedFilters.removeAll { $0.id == id }
    }
  }

  func loadProfile(into state: inout State) -> Effect<Action> {
    state.isLoading = true
    state.errorMessage = nil

    let userClient = self.userClient
    let filterClient = self.filterClient
    let sessionClient = self.sessionClient

    return .run { send in
      do {
        // 좋아하는 필터는 userID 의존이 없으므로 즉시 병렬 호출.
        async let likedTask = filterClient.likedFilters(
          UserFilterListQuery(next: nil, limit: 20, category: nil)
        )

        let myProfile = try await userClient.fetchMyProfile()

        let candidateFromProfile = myProfile.userID.trimmed
        let effectiveUserID: String?
        if !candidateFromProfile.isEmpty {
          effectiveUserID = candidateFromProfile
        } else {
          // user_id가 비어 있으면 세션 스냅샷에서 폴백.
          let snapshot = await sessionClient.snapshot()
          let candidate = (snapshot.currentUserID ?? "").trimmed
          effectiveUserID = candidate.isEmpty ? nil : candidate
        }

        // 내 필터 목록은 user_id 확정 이후에만 호출.
        let userFiltersResponse: FilterSummaryPaginationListResponseDTO?
        if let userID = effectiveUserID {
          userFiltersResponse = try await filterClient.userFilters(
            userID,
            UserFilterListQuery(next: nil, limit: 30, category: nil)
          )
        } else {
          userFiltersResponse = nil
        }

        let likedResponse = try await likedTask

        let likedItems = ProfileResponseParser.likedFilters(from: likedResponse.data)
        let userFilterItems = userFiltersResponse.map {
          ProfileResponseParser.userFilterListItems(from: $0.data)
        } ?? []

        let featured = userFilterItems
          .sorted(by: { $0.likeCount > $1.likeCount })
          .first
          .map { ProfileResponseParser.featuredFilter(from: $0) }

        let summary = ProfileResponseParser.summary(
          from: myProfile,
          userID: effectiveUserID ?? "",
          filterCount: userFilterItems.count,
          likedCount: likedItems.count
        )

        let loaded = LoadedProfile(
          summary: summary,
          featuredFilter: featured,
          likedFilters: likedItems,
          currentUserID: effectiveUserID
        )
        await send(.profileLoadResponse(.success(loaded)))
      } catch {
        await send(.profileLoadResponse(.failure(error)))
      }
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
        return "인증 정보가 없어 마이 화면을 불러올 수 없어요."

      case let .invalidSession(statusCode):
        return "세션이 유효하지 않습니다. 다시 로그인해 주세요. (\(statusCode))"

      case let .server(statusCode, message, _):
        if let message, !message.isEmpty {
          return message
        }
        return "서버 응답을 불러오지 못했어요. (\(statusCode))"
      }
    }

    return "마이 화면을 불러오지 못했어요. 잠시 후 다시 시도해 주세요."
  }
}
