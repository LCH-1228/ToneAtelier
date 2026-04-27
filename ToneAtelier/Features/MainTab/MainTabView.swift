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
  }

  private var shouldShowTabBar: Bool {
    !(store.selectedTab == .home && store.home.bannerWebView != nil)
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
            store: store.scope(state: \.feed, action: \.feed)
          ) {
            store.send(.feedBackButtonTapped)
          }
        }
      }

      tabRoot(.video) {
        NavigationStack {
          videoPlaceholder
        }
      }

      tabRoot(.chat) {
        NavigationStack {
          chatPlaceholder
        }
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

  private var videoPlaceholder: some View {
    TabPlaceholderView(
      title: "비디오",
      subtitle: "숏폼 피드와 좋아요, 스트림 재생이 들어올 탭입니다.",
      details: [
        "비디오 피드",
        "재생 화면",
        "좋아요 상태"
      ],
      symbolName: "play.rectangle.fill",
      accentColor: Color(red: 0.95, green: 0.34, blue: 0.33)
    ) {
      store.send(.logoutButtonTapped)
    }
  }

  private var chatPlaceholder: some View {
    TabPlaceholderView(
      title: "채팅",
      subtitle: "채팅방 목록과 메시지 화면이 연결될 영역입니다.",
      details: [
        "채팅방 리스트",
        "읽지 않은 메시지 배지",
        "채팅 상세 화면"
      ],
      symbolName: "bubble.left.and.bubble.right.fill",
      accentColor: Color(red: 0.33, green: 0.58, blue: 0.96)
    ) {
      store.send(.logoutButtonTapped)
    }
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
