//
//  ProfileFeature.swift
//  ToneAtelier
//
//  Created by Codex on 5/1/26.
//

import ComposableArchitecture
import Foundation

// TODO: 응답 추출 helper는 후속 브랜치에서 전용 Decodable DTO로 대체.
// TODO: 통계 카운트는 임시(필터 수·좋아요 합산·좋아하는 필터 수)이며 후속 브랜치에서 정확화.

@Reducer
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
    var detail: HomeDetailFeature.State?
    var likedFiltersList: LikedFiltersFeature.State?
    var creatorStore: CreatorStoreFeature.State?
    var editProfile: ProfileEditFeature.State?
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
    // TODO: 설정 화면 디자인 확정 후 별도 브랜치에서 navigation 연결.
    case settingsButtonTapped
    case editProfileButtonTapped
    case creatorShopButtonTapped
    case featuredFilterTapped
    case likedFilterTapped(LikedFilter.ID)
    case viewAllLikesTapped
    case detail(HomeDetailFeature.Action)
    case detailDismissed
    case likedFiltersList(LikedFiltersFeature.Action)
    case likedFiltersListDismissed
    case creatorStore(CreatorStoreFeature.Action)
    case creatorStoreDismissed
    case editProfile(ProfileEditFeature.Action)
    case editProfileDismissed
  }

  var body: some Reducer<State, Action> {
    BindingReducer()
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

      case .featuredFilterTapped:
        guard let filter = state.featuredFilter else { return .none }
        state.detail = HomeDetailFeature.State(profileFeaturedFilter: filter)
        return .none

      case let .likedFilterTapped(id):
        guard let filter = state.likedFilters.first(where: { $0.id == id }) else { return .none }
        state.detail = HomeDetailFeature.State(likedFilter: filter)
        return .none

      case let .detail(.delegate(.likeStatusChanged(id, isLiked, likeCount))):
        // 좋아요 해제(false)이면 마이 화면 미리보기에서도 제거,
        // 그 외에는 isLiked/likeCount만 동기화(Major #11 — likeCount nil도 ±1 보정).
        if isLiked {
          state.likedFilters = state.likedFilters.map { liked in
            liked.id == id ? liked.settingLike(isLiked, likeCount: likeCount) : liked
          }
        } else {
          state.likedFilters.removeAll { $0.id == id }
        }
        return .none

      case .detail:
        return .none

      case .detailDismissed:
        state.detail = nil
        return .none

      case .viewAllLikesTapped:
        state.likedFiltersList = LikedFiltersFeature.State()
        return .none

      case let .likedFiltersList(.delegate(.likeStatusChanged(id, likeCount, isLiked))):
        // 좋아하는 필터 목록에서 좋아요 해제 → 마이 화면 미리보기에서도 제거,
        // 토글 유지/회복 → settingLike로 동기화(Major #11 — likeCount nil도 안전 처리).
        if isLiked {
          state.likedFilters = state.likedFilters.map { liked in
            liked.id == id ? liked.settingLike(isLiked, likeCount: likeCount) : liked
          }
        } else {
          state.likedFilters.removeAll { $0.id == id }
        }
        return .none

      case .likedFiltersList:
        return .none

      case .likedFiltersListDismissed:
        state.likedFiltersList = nil
        return .none

      case .creatorShopButtonTapped:
        guard let userID = state.currentUserID, !userID.isEmpty else {
          // user_id가 비어 있으면 작가 스토어 진입을 막는다.
          // 마이 화면 데이터 연동이 끝났는데도 user_id가 없는 케이스(세션 폴백 실패).
          return .none
        }
        state.creatorStore = CreatorStoreFeature.State(
          userID: userID,
          isOwn: true,
          headerName: state.summary.nickname
        )
        return .none

      case let .creatorStore(.delegate(.likeStatusChanged(id, likeCount, isLiked))):
        // 작가 스토어에서 좋아요 변동 → 마이 화면의 "좋아한 필터" 미리보기에 동기화.
        // 좋아요 해제 시 미리보기에서도 제거(LikedFilters 정책과 동일).
        if isLiked {
          state.likedFilters = state.likedFilters.map { liked in
            liked.id == id ? liked.settingLike(isLiked, likeCount: likeCount) : liked
          }
        } else {
          state.likedFilters.removeAll { $0.id == id }
        }
        return .none

      case .creatorStore:
        return .none

      case .creatorStoreDismissed:
        state.creatorStore = nil
        return .none

      case .editProfileButtonTapped:
        state.editProfile = ProfileEditFeature.State(
          nickname: state.summary.nickname,
          email: state.summary.email,
          name: state.summary.name,
          phoneNum: state.summary.phoneNum ?? "",
          introduction: state.summary.bio,
          hashTags: state.summary.hashTags,
          avatarURL: state.summary.avatarURL
        )
        return .none

      case let .editProfile(.delegate(.profileUpdated(saved))):
        // SavedProfile은 nickname/introduction/phoneNum/hashTags/avatarURL만 포함.
        // name/email은 편집 불가이므로 그대로 두고, 변경된 필드만 summary에 반영한다.
        state.summary.nickname = saved.nickname
        state.summary.bio = saved.introduction
        state.summary.phoneNum = saved.phoneNum.isEmpty ? nil : saved.phoneNum
        state.summary.hashTags = saved.hashTags
        state.summary.avatarURL = saved.avatarURL
        state.editProfile = nil
        return .none

      case .editProfile(.delegate(.dismissRequested)):
        state.editProfile = nil
        return .none

      case .editProfile:
        return .none

      case .editProfileDismissed:
        state.editProfile = nil
        return .none

      case .settingsButtonTapped:
        return .none
      }
    }
    .ifLet(\.detail, action: \.detail) {
      HomeDetailFeature()
    }
    .ifLet(\.likedFiltersList, action: \.likedFiltersList) {
      LikedFiltersFeature()
    }
    .ifLet(\.creatorStore, action: \.creatorStore) {
      CreatorStoreFeature()
    }
    .ifLet(\.editProfile, action: \.editProfile) {
      ProfileEditFeature()
    }
  }

  private func loadProfile(into state: inout State) -> Effect<Action> {
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

        let candidateFromProfile = myProfile.user_id.trimmed
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
        let userFiltersJSON: JSONValue?
        if let userID = effectiveUserID {
          userFiltersJSON = try await filterClient.userFilters(
            userID,
            UserFilterListQuery(next: nil, limit: 30, category: nil)
          )
        } else {
          userFiltersJSON = nil
        }

        let likedJSON = try await likedTask

        let likedItems = ProfileResponseParser.likedFilters(from: likedJSON)
        let userFilterItems = userFiltersJSON.map {
          ProfileResponseParser.userFilterListItems(from: $0)
        } ?? []

        let featured = userFilterItems
          .sorted(by: { $0.likeCount > $1.likeCount })
          .first
          .map { ProfileResponseParser.featuredFilter(from: $0) }

        let totalLikes = userFilterItems.reduce(0) { $0 + $1.likeCount }

        let summary = ProfileResponseParser.summary(
          from: myProfile,
          userID: effectiveUserID ?? "",
          filterCount: userFilterItems.count,
          likedCount: likedItems.count,
          totalLikes: totalLikes
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
