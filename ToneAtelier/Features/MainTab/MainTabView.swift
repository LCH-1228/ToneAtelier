//
//  MainTabView.swift
//  ToneAtelier
//
//  Created by Codex on 4/23/26.
//

import ComposableArchitecture
import SwiftUI

struct MainTabView: View {
  @Bindable var store: StoreOf<MainTabFeature>

  var body: some View {
    TabView(selection: $store.selectedTab) {
      Tab(
        MainTab.home.accessibilityLabel,
        image: MainTab.home.iconName(isSelected: store.selectedTab == .home),
        value: MainTab.home
      ) {
        GeometryReader { proxy in
          HomeView(
            store: store.scope(state: \.home, action: \.home),
            topSafeAreaInset: proxy.safeAreaInsets.top
          )
        }
      }

      Tab(
        MainTab.feed.accessibilityLabel,
        image: MainTab.feed.iconName(isSelected: store.selectedTab == .feed),
        value: MainTab.feed
      ) {
        FeedView(
          store: store.scope(state: \.feed, action: \.feed),
          backAction: feedBackHandler()
        )
      }

      Tab(
        MainTab.post.accessibilityLabel,
        image: MainTab.post.iconName(isSelected: store.selectedTab == .post),
        value: MainTab.post
      ) {
        PostView(store: store.scope(state: \.post, action: \.post))
      }

      Tab(
        MainTab.chat.accessibilityLabel,
        image: MainTab.chat.iconName(isSelected: store.selectedTab == .chat),
        value: MainTab.chat
      ) {
        ChatTabView(store: store.scope(state: \.chat, action: \.chat))
      }
      .badge(store.chatUnreadTotal)

      Tab(
        MainTab.profile.accessibilityLabel,
        image: MainTab.profile.iconName(isSelected: store.selectedTab == .profile),
        value: MainTab.profile
      ) {
        ProfileView(store: store.scope(state: \.profile, action: \.profile))
      }
    }
    .background(AppTheme.background.ignoresSafeArea())
    .preferredColorScheme(.dark)
    .alert($store.scope(state: \.logoutConfirmation, action: \.alert))
    .alert($store.scope(state: \.messageFailureAlert, action: \.messageFailureAlert))
    .task { await store.send(.task).finish() }
  }

  private func feedBackHandler() -> (() -> Void)? {
    guard store.showsFeedBackButton else { return nil }
    return { store.send(.feedBackButtonTapped) }
  }
}

#Preview {
  MainTabView(
    store: Store(initialState: MainTabFeature.State()) {
      MainTabFeature()
    }
  )
}
