//
//  ChatTabView.swift
//  ToneAtelier
//
//  Created by LCH on 4/29/26.
//

import ComposableArchitecture
import SwiftUI

/// 채팅 탭 루트. NavigationStack을 직접 보유하고
/// 우상단에 새 채팅 검색 버튼을 노출한다.
struct ChatTabView: View {
  @Bindable var store: StoreOf<ChatTabFeature>

  var body: some View {
    NavigationStack(
      path: $store.scope(state: \.path, action: \.path)
    ) {
      ChatListView(
        store: store.scope(state: \.list, action: \.list)
      )
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("새 채팅", systemImage: "square.and.pencil") {
            store.send(.searchButtonTapped)
          }
          .tint(.white)
        }
      }
    } destination: { store in
      switch store.case {
      case let .chatRoom(store):
        ChatRoomView(store: store)
      case let .search(store):
        ChatSearchView(store: store)
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
