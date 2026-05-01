//
//  ChatListView.swift
//  ToneAtelier
//
//  Created by LCH on 4/29/26.
//

import ComposableArchitecture
import SwiftUI

/// 채팅방 목록 화면.
/// `NavigationStack`은 단계 4에서 부모(MainTab/ChatTabFeature)가 감싸므로
/// 여기서는 컨텐츠만 제공한다. 행 탭은 `delegate(.roomTapped)`로 위임된다.
struct ChatListView: View {
  @Bindable var store: StoreOf<ChatListFeature>

  var body: some View {
    ZStack {
      AppTheme.background.ignoresSafeArea()
      content
    }
    .safeAreaInset(edge: .bottom) {
      // MainTabBar에 가려지는 영역을 회피한다. 탭바 높이가 단일 진실의 원천.
      Color.clear.frame(height: MainTabBarView.Layout.contentInsetHeight)
    }
    .navigationTitle("채팅")
    .navigationBarTitleDisplayMode(.large)
    .alert($store.scope(state: \.alert, action: \.alert))
    .task { await store.send(.task).finish() }
  }

  // MARK: - Content states

  @ViewBuilder
  private var content: some View {
    if store.rooms.isEmpty {
      if store.isLoading {
        loadingView
      } else {
        emptyView
      }
    } else {
      list
    }
  }

  private var loadingView: some View {
    VStack(spacing: 12) {
      ProgressView()
        .progressViewStyle(.circular)
        .tint(AppTheme.gray45)
      Text("채팅방을 불러오는 중...")
        .font(AppTheme.pretendard(size: 14, weight: .regular))
        .foregroundStyle(AppTheme.gray60)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var emptyView: some View {
    VStack(spacing: 12) {
      Image(systemName: "bubble.left.and.bubble.right")
        .font(.system(size: 48, weight: .light))
        .foregroundStyle(AppTheme.gray60)
      Text("아직 채팅방이 없어요")
        .font(AppTheme.pretendard(size: 16, weight: .semibold))
        .foregroundStyle(.white)
      Text("관심 있는 작가와 대화를 시작해 보세요")
        .font(AppTheme.pretendard(size: 13, weight: .regular))
        .foregroundStyle(AppTheme.gray60)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var list: some View {
    List {
      ForEach(store.rooms, id: \.room_id) { room in
        Button {
          store.send(.rowTapped(room))
        } label: {
          ChatRoomRowView(
            room: room,
            currentUserID: store.currentUserID,
            baseURL: store.baseURL
          )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("채팅방 열기")
        .listRowBackground(AppTheme.background)
        .listRowSeparatorTint(AppTheme.deepTurquoise)
        .listRowInsets(EdgeInsets())
      }
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .background(AppTheme.background)
    .refreshable {
      await store.send(.refreshRequested).finish()
    }
  }
}

#Preview {
  NavigationStack {
    ChatListView(
      store: Store(initialState: ChatListFeature.State()) {
        ChatListFeature()
      }
    )
  }
  .preferredColorScheme(.dark)
}
