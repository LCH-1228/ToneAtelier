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
    GeometryReader { proxy in
      tabContent(topSafeAreaInset: proxy.safeAreaInsets.top)
        .safeAreaInset(edge: .bottom, spacing: 0) {
          if shouldShowTabBar {
            MainTabBarView(selectedTab: $store.selectedTab)
              .padding(.top, MainTabBarView.Layout.topClearance)
              .transition(.move(edge: .bottom).combined(with: .opacity))
          }
        }
    }
    .background(AppTheme.background.ignoresSafeArea())
    .preferredColorScheme(.dark)
    .animation(.easeInOut(duration: 0.18), value: shouldShowTabBar)
    .alert($store.scope(state: \.logoutConfirmation, action: \.alert))
    .task { await store.send(.task).finish() }
  }

  private var shouldShowTabBar: Bool {
    if store.selectedTab == .home,
       case .bannerWeb = store.home.path.last {
      return false
    }

    // if store.selectedTab == .make && store.make.edit != nil {
    //   return false
    // }

    // 채팅방/검색 화면 진입 시 키보드 + 입력바 + 탭바가 동시에 쌓이지 않도록 탭바를 숨긴다.
    if store.selectedTab == .chat && !store.chat.path.isEmpty {
      return false
    }

    return true
  }

  private func feedBackAction() {
    store.send(.feedBackButtonTapped)
  }

  private func feedBackHandler() -> (() -> Void)? {
    guard store.showsFeedBackButton else { return nil }
    return feedBackAction
  }

  private func tabContent(topSafeAreaInset: CGFloat) -> some View {
    ZStack {
      tabRoot(.home) {
        HomeView(
          store: store.scope(state: \.home, action: \.home),
          topSafeAreaInset: topSafeAreaInset
        )
      }

      tabRoot(.feed) {
        FeedView(
          store: store.scope(state: \.feed, action: \.feed),
          backAction: feedBackHandler()
        )
      }

      // tabRoot(.make) {
      //   NavigationStack {
      //     MakeView(
      //       store: store.scope(state: \.make, action: \.make)
      //     )
      //   }
      // }

      tabRoot(.post) {
        PostView(
          store: store.scope(state: \.post, action: \.post)
        )
      }

      tabRoot(.chat) {
        ChatTabView(
          store: store.scope(state: \.chat, action: \.chat)
        )
      }

      tabRoot(.profile) {
        NavigationStack {
          ProfileView(
            store: store.scope(state: \.profile, action: \.profile)
          )
        }
      }
    }
  }

  private func tabRoot<Content: View>(
    _ tab: MainTab,
    @ViewBuilder content: () -> Content
  ) -> some View {
    content()
      .opacity(store.selectedTab == tab ? 1 : 0)
      .allowsHitTesting(store.selectedTab == tab)
      .accessibilityHidden(store.selectedTab != tab)
  }
}

#Preview {
  MainTabView(
    store: Store(initialState: MainTabFeature.State()) {
      MainTabFeature()
    }
  )
}
