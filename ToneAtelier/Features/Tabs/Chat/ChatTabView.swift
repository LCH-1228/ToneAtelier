//
//  ChatTabView.swift
//  ToneAtelier
//
//  Created by LCH on 4/29/26.
//

import ComposableArchitecture
import SwiftUI

/// 채팅 탭 루트. NavigationStack을 직접 보유한다.
struct ChatTabView: View {
  @Bindable var store: StoreOf<ChatTabFeature>

  var body: some View {
    NavigationStack(
      path: $store.scope(state: \.path, action: \.path)
    ) {
      ChatListView(
        store: store.scope(state: \.list, action: \.list),
        searchEntryAction: { store.send(.searchButtonTapped) }
      )
    } destination: { store in
      switch store.case {
      case let .chatRoom(store):
        ChatRoomView(store: store)
      case let .search(store):
        ChatSearchView(store: store)
      case let .userProfile(store):
        UserProfileView(store: store)
      case let .creatorStore(store):
        CreatorStoreView(store: store)
      case let .detail(store):
        HomeDetailView(store: store)
      }
    }
    // 채팅방/검색 화면을 모두 pop해 root(ChatList)로 돌아왔을 때
    // 리스트 lastChat/정렬을 한 번 더 동기화한다(C3 redundant safety).
    // 자식 delegate.messageHandled 경로가 이미 트리거됐다면 ChatList의 isLoading guard로 중복은 무시된다.
    .onChange(of: store.path.isEmpty) { _, isEmpty in
      if isEmpty {
        store.send(.list(.refreshRequested))
      }
    }
  }
}

#Preview {
  ChatTabView(
    store: Store(initialState: ChatTabFeature.State()) {
      ChatTabFeature()
    }
  )
  .preferredColorScheme(.dark)
}
