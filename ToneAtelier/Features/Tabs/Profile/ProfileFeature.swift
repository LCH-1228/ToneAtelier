//
//  ProfileFeature.swift
//  ToneAtelier
//
//  Created by Codex on 5/1/26.
//

import ComposableArchitecture
import Foundation

// TODO: 응답 추출 helper는 후속 브랜치에서 전용 Decodable DTO로 대체.
// TODO: 통계 카운트는 임시(필터 수·좋아요 합산·좋아한 필터 수)이며 후속 브랜치에서 정확화.

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
  }

  struct LoadedProfile: Equatable, Sendable {
    var summary: ProfileSummary
    var featuredFilter: FeaturedFilter?
    var likedFilters: [LikedFilter]
    var currentUserID: String?
  }

  enum Action: Sendable {
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
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
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

      case let .detail(.delegate(.likeStatusChanged(id, _, likeCount))):
        state.likedFilters = state.likedFilters.map { liked in
          liked.id == id ? liked.settingLikeCount(likeCount) : liked
        }
        return .none

      case .detail:
        return .none

      case .detailDismissed:
        state.detail = nil
        return .none

      case .settingsButtonTapped,
           .editProfileButtonTapped,
           .creatorShopButtonTapped,
           .viewAllLikesTapped:
        return .none
      }
    }
    .ifLet(\.detail, action: \.detail) {
      HomeDetailFeature()
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
        // 좋아한 필터는 userID 의존이 없으므로 즉시 병렬 호출.
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
