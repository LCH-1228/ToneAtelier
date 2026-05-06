//
//  ChatListView.swift
//  ToneAtelier
//
//  Created by LCH on 4/29/26.
//

import ComposableArchitecture
import SwiftUI

struct ChatListView: View {
  @Bindable var store: StoreOf<ChatListFeature>
  let searchEntryAction: () -> Void

  @FocusState private var isSearchFocused: Bool

  var body: some View {
    VStack(spacing: 0) {
      searchField
      if isSearchFocused && store.query.isEmpty && !store.recentSearches.isEmpty {
        ChatRecentSearchView(
          keywords: store.recentSearches,
          onTap: { keyword in
            store.send(.recentSearchTapped(keyword))
            isSearchFocused = false
          },
          onClearAll: { store.send(.recentClearAllTapped) }
        )
      }
      filterChips
      content
    }
    .background(AppTheme.background.ignoresSafeArea())
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(AppTheme.background, for: .navigationBar)
    .toolbarColorScheme(.dark, for: .navigationBar)
    .toolbar {
      PrincipalToolbarTitle("CHAT")
      PlainToolbarItem(placement: .topBarTrailing) {
        Button(action: searchEntryAction) {
          Image(AppAsset.Common.searchUser)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 22, height: 22)
            .foregroundStyle(Color.white)
            .frame(width: 44, height: 44)
            .contentShape(.rect)
        }
        .accessibilityLabel("사용자 검색")
      }
    }
    .alert($store.scope(state: \.alert, action: \.alert))
    .task { await store.send(.task).finish() }
  }

  // MARK: - Header pieces

  private var searchField: some View {
    HStack(spacing: 8) {
      Image(systemName: "magnifyingglass")
        .foregroundStyle(AppTheme.gray60)
      TextField(
        "",
        text: $store.query,
        prompt: Text("대화 검색")
          .foregroundStyle(AppTheme.gray60)
          .font(AppTheme.Pretendard.body2.font)
      )
      .focused($isSearchFocused)
      .font(AppTheme.Pretendard.body2.font)
      .textInputAutocapitalization(.never)
      .autocorrectionDisabled()
      .submitLabel(.search)
      .onSubmit { store.send(.searchSubmitted) }
      .foregroundStyle(.white)
      .tint(.white)

      if !store.query.isEmpty {
        Button {
          store.query = ""
        } label: {
          Image(systemName: "xmark.circle.fill")
            .foregroundStyle(AppTheme.gray60)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("입력 지우기")
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .background(AppTheme.blackTurquoise, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .padding(.horizontal, 20)
    .padding(.bottom, 12)
  }

  private var filterChips: some View {
    HStack(spacing: 8) {
      ForEach(ChatListFilter.allCases, id: \.self) { filter in
        Button {
          store.send(.filterSelected(filter))
        } label: {
          Text(filter.title)
            .pretendard(.body3)
            .foregroundStyle(store.filter == filter ? .white : AppTheme.gray60)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
              Capsule()
                .fill(store.filter == filter ? AppTheme.deepTurquoise : AppTheme.blackTurquoise)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(store.filter == filter ? .isSelected : [])
      }
      Spacer()
    }
    .padding(.horizontal, 20)
    .padding(.bottom, 8)
  }

  // MARK: - Content states

  @ViewBuilder
  private var content: some View {
    let displayed = store.displayedRooms
    if store.rooms.isEmpty {
      if store.isLoading {
        loadingView
      } else {
        emptyView
      }
    } else if displayed.isEmpty {
      noMatchView
    } else {
      list(displayed)
    }
  }

  private var loadingView: some View {
    VStack(spacing: 12) {
      ProgressView()
        .progressViewStyle(.circular)
        .tint(AppTheme.gray45)
      Text("채팅방을 불러오는 중...")
        .pretendard(.body2)
        .foregroundStyle(AppTheme.gray60)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var emptyView: some View {
    VStack(spacing: 12) {
      Image(systemName: "bubble.left.and.bubble.right")
        .font(AppTheme.symbol(size: 48, weight: .light))
        .foregroundStyle(AppTheme.gray60)
      Text("아직 채팅방이 없어요")
        .pretendard(.body1)
        .foregroundStyle(.white)
      Text("관심 있는 작가와 대화를 시작해 보세요")
        .pretendard(.body3)
        .foregroundStyle(AppTheme.gray60)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var noMatchView: some View {
    VStack(spacing: 12) {
      Image(systemName: "magnifyingglass")
        .font(AppTheme.symbol(size: 44, weight: .light))
        .foregroundStyle(AppTheme.gray60)
      Text("일치하는 채팅방이 없어요")
        .pretendard(.body1)
        .foregroundStyle(.white)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func list(_ rooms: [ChatRoom]) -> some View {
    List {
      ForEach(rooms, id: \.roomID) { room in
        Button {
          store.send(.rowTapped(room))
        } label: {
          ChatRoomRowView(
            room: room,
            unreadCount: store.unreadCounts[room.roomID] ?? 0,
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
      },
      searchEntryAction: {}
    )
  }
  .preferredColorScheme(.dark)
}
