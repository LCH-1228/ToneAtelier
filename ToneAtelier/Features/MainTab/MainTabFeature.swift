//
//  MainTabFeature.swift
//  ToneAtelier
//
//  Created by Codex on 4/23/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct MainTabFeature {
  @ObservableState
  struct State: Equatable {
    @Presents var logoutConfirmation: AlertState<Action.Alert>?
    var home = HomeFeature.State()
    var feed = FeedFeature.State(category: nil)
    var make = MakeFeature.State()
    var chat = ChatTabFeature.State()
    var profile = ProfileFeature.State()
    var showsFeedBackButton = false
    var selectedTab: MainTab = .home
  }

  enum Action: BindableAction, Sendable {
    case alert(PresentationAction<Alert>)
    case binding(BindingAction<State>)
    case chat(ChatTabFeature.Action)
    case delegate(Delegate)
    case feed(FeedFeature.Action)
    case feedBackButtonTapped
    case home(HomeFeature.Action)
    case logoutButtonTapped
    case make(MakeFeature.Action)
    case profile(ProfileFeature.Action)

    enum Alert: Equatable, Sendable {
      case confirmLogout
    }

    enum Delegate: Equatable, Sendable {
      case logoutRequested
    }
  }

  var body: some Reducer<State, Action> {
    Scope(state: \.home, action: \.home) {
      HomeFeature()
    }

    Scope(state: \.feed, action: \.feed) {
      FeedFeature()
    }

    Scope(state: \.make, action: \.make) {
      MakeFeature()
    }

    Scope(state: \.chat, action: \.chat) {
      ChatTabFeature()
    }

    Scope(state: \.profile, action: \.profile) {
      ProfileFeature()
    }

    BindingReducer()

    Reduce { state, action in
      switch action {
      case .alert(.presented(.confirmLogout)):
        // 사용자가 confirmation alert에서 "로그아웃"을 선택한 경우에만 부모로 위임한다.
        // alert dismiss/cancel 경로는 별도 상태 변경 없이 기본 동작에 맡긴다.
        return .send(.delegate(.logoutRequested))

      case .alert:
        return .none

      case .binding(\.selectedTab):
        state.showsFeedBackButton = false
        return .none

      case .binding:
        return .none

      case .chat:
        return .none

      case .feed:
        return .none

      case .feedBackButtonTapped:
        state.showsFeedBackButton = false
        state.selectedTab = .home
        return .none

      case .make:
        return .none

      case .profile:
        return .none

      case let .home(.delegate(.feedCategorySelected(category))):
        state.feed = FeedFeature.State(category: category)
        state.showsFeedBackButton = true
        state.selectedTab = .feed
        return .none

      case .home:
        return .none

      case .logoutButtonTapped:
        // 로그아웃은 채팅 내역과 사진 캐시를 모두 지우는 destructive 동작이므로
        // 곧바로 delegate를 발사하지 않고 confirmation alert로 한 번 더 확인을 받는다.
        state.logoutConfirmation = AlertState {
          TextState("로그아웃하시겠습니까?")
        } actions: {
          ButtonState(role: .cancel) {
            TextState("취소")
          }
          ButtonState(role: .destructive, action: .confirmLogout) {
            TextState("로그아웃")
          }
        } message: {
          TextState("이 기기에 저장된 채팅 내역과 사진이 모두 삭제됩니다.")
        }
        return .none

      case .delegate:
        return .none
      }
    }
    .ifLet(\.$logoutConfirmation, action: \.alert)
  }
}
