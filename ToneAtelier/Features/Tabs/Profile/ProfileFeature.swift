//
//  ProfileFeature.swift
//  ToneAtelier
//
//  Created by Codex on 5/1/26.
//

import ComposableArchitecture
import Foundation

// TODO: feat/profile-interaction에서 다음 매핑을 결합한다.
// • userClient.fetchMyProfile → state.summary
// • filterClient.userFilters(myUserID) → likeCount desc 정렬 후 1개 → state.featuredFilter
// • filterClient.likedFilters → state.likedFilters
// • filterClient.detail / setLike, userClient.updateMyProfile / uploadProfileImage

@Reducer
struct ProfileFeature {
  @ObservableState
  struct State: Equatable {
    var summary: ProfileSummary = .placeholder
    var featuredFilter: FeaturedFilter? = .placeholder
    var likedFilters: [LikedFilter] = LikedFilter.placeholders
  }

  enum Action: Sendable {
    case settingsButtonTapped
    case editProfileButtonTapped
    case creatorShopButtonTapped
    case featuredFilterTapped
    case likedFilterTapped(LikedFilter.ID)
    case viewAllLikesTapped
  }

  var body: some Reducer<State, Action> {
    Reduce { _, _ in
      .none
    }
  }
}
