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

  init(store: StoreOf<MainTabFeature>) {
    self.store = store
  }

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
    .background(HomeTheme.background.ignoresSafeArea())
    .preferredColorScheme(.dark)
    .animation(.easeInOut(duration: 0.18), value: shouldShowTabBar)
    .alert($store.scope(state: \.logoutConfirmation, action: \.alert))
  }

  private var shouldShowTabBar: Bool {
    if store.selectedTab == .home && store.home.bannerWebView != nil {
      return false
    }

    if store.selectedTab == .make && store.make.edit != nil {
      return false
    }

    // 채팅방/검색 화면 진입 시 키보드 + 입력바 + 탭바가 동시에 쌓이지 않도록 탭바를 숨긴다.
    if store.selectedTab == .chat && !store.chat.path.isEmpty {
      return false
    }

    return true
  }

  private var feedBackAction: () -> Void {
    {
      store.send(.feedBackButtonTapped)
    }
  }

  private func tabContent(topSafeAreaInset: CGFloat) -> some View {
    ZStack {
      tabRoot(.home) {
        NavigationStack {
          HomeView(
            store: store.scope(state: \.home, action: \.home),
            topSafeAreaInset: topSafeAreaInset
          )
        }
      }

      tabRoot(.feed) {
        NavigationStack {
          FeedView(
            store: store.scope(state: \.feed, action: \.feed),
            backAction: store.showsFeedBackButton ? feedBackAction : nil
          )
        }
      }

      tabRoot(.make) {
        NavigationStack {
          MakeView(
            store: store.scope(state: \.make, action: \.make)
          )
        }
      }

      tabRoot(.chat) {
        ChatTabView(
          store: store.scope(state: \.chat, action: \.chat)
        )
      }

      tabRoot(.profile) {
        NavigationStack {
          profilePlaceholder
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

  private var profilePlaceholder: some View {
    TabPlaceholderView(
      title: "마이",
      subtitle: "프로필, 좋아요, 주문 내역이 들어올 개인 영역입니다.",
      details: [
        "내 프로필",
        "좋아요/저장 목록",
        "주문 및 결제 내역"
      ],
      symbolName: "person.crop.circle.fill",
      accentColor: Color(red: 0.62, green: 0.48, blue: 0.92)
    ) {
      store.send(.logoutButtonTapped)
    }
  }
}

#Preview {
  MainTabView(
    store: Store(initialState: MainTabFeature.State()) {
      MainTabFeature()
    }
  )
}
