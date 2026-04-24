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
    ZStack(alignment: .bottom) {
      currentTabContent
        .safeAreaInset(edge: .bottom) {
          Color.clear.frame(height: 88)
        }

      MainTabBarView(selectedTab: $store.selectedTab)
    }
    .background(HomeTheme.background.ignoresSafeArea())
    .preferredColorScheme(.dark)
  }

  @ViewBuilder
  private var currentTabContent: some View {
    switch store.selectedTab {
    case 0:
      NavigationStack {
        HomeView(
          store: store.scope(state: \.home, action: \.home)
        )
      }

    case 1:
      NavigationStack {
        TabPlaceholderView(
          title: "필터",
          subtitle: "트렌드 필터와 오늘의 필터, 상세 진입이 들어올 탭입니다.",
          details: [
            "실시간 트렌드",
            "오늘의 필터",
            "필터 상세 진입"
          ],
          symbolName: "camera.filters",
          accentColor: Color(red: 0.37, green: 0.77, blue: 0.69)
        ) {
          store.send(.logoutButtonTapped)
        }
      }

    case 2:
      NavigationStack {
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

    case 3:
      NavigationStack {
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

    default:
      NavigationStack {
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
  }
}

#Preview {
  MainTabView(
    store: Store(initialState: MainTabFeature.State()) {
      MainTabFeature()
    }
  )
}
