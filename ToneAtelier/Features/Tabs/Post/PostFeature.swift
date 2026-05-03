//
//  PostFeature.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct PostFeature {
  @ObservableState
  struct State: Equatable {
    var posts: [PostSummaryResponseDTO] = []
    var order: PostListOrder = .createdAt
    var isFirstLoading: Bool = false
    var isPaginating: Bool = false
    var hasLoadedOnce: Bool = false
    /// FeedFeature 동일 컨벤션: "0"은 더 이상 페이지가 없다는 sentinel.
    var nextCursor: String = "0"
    var errorMessage: String?

    var isLocationDenied: Bool = false
    var currentLatitude: Double?
    var currentLongitude: Double?
  }

  enum Action: BindableAction, Sendable {
    case binding(BindingAction<State>)
    case task
    case orderTabTapped(PostListOrder)
    case lastCardAppeared(postID: String)
    case cardTapped(postID: String)
    case cardLikeToggled(postID: String, currentIsLike: Bool)
    case authorTapped(userID: String)
    case searchEntryTapped
    case writeButtonTapped
    case locationPermissionBannerTapped
    case delegate(Delegate)

    enum Delegate: Equatable, Sendable {
      case userPostsRequested(userID: String)
    }
  }

  var body: some Reducer<State, Action> {
    BindingReducer()
    Reduce { _, action in
      switch action {
      case .binding:
        return .none
      case .task,
           .orderTabTapped,
           .lastCardAppeared,
           .cardTapped,
           .cardLikeToggled,
           .searchEntryTapped,
           .writeButtonTapped,
           .locationPermissionBannerTapped:
        return .none
      case let .authorTapped(userID):
        return .send(.delegate(.userPostsRequested(userID: userID)))
      case .delegate:
        return .none
      }
    }
  }
}
