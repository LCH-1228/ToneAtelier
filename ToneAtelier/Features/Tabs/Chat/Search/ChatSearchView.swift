//
//  ChatSearchView.swift
//  ToneAtelier
//
//  Created by LCH on 4/29/26.
//

import ComposableArchitecture
import SwiftUI

struct ChatSearchView: View {
  @Bindable var store: StoreOf<ChatSearchFeature>

  var body: some View {
    VStack(spacing: 0) {
      searchField
      if !store.recentSearches.isEmpty {
        ChatRecentSearchView(
          keywords: store.recentSearches,
          onTap: { store.send(.recentSearchTapped($0)) },
          onClearAll: { store.send(.recentClearAllTapped) }
        )
      }
      if !store.results.isEmpty {
        resultsHeader
      }
      content
    }
    .background(AppTheme.background.ignoresSafeArea())
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(AppTheme.background, for: .navigationBar)
    .toolbarColorScheme(.dark, for: .navigationBar)
    .toolbar {
      ToolbarItem(placement: .principal) {
        Text("SEARCH")
          .mulgyeol(.bodyNormal)
          .foregroundStyle(AppTheme.gray60)
      }
    }
    .alert($store.scope(state: \.alert, action: \.alert))
    .overlay {
      if store.isCreatingRoom {
        creatingOverlay
      }
    }
    .task { await store.send(.task).finish() }
  }

  // MARK: - Search field

  private var searchField: some View {
    HStack(spacing: 8) {
      Image(systemName: "magnifyingglass")
        .foregroundStyle(AppTheme.gray60)
      TextField(
        "",
        text: $store.query,
        prompt: Text("닉네임을 검색하세요")
          .foregroundStyle(AppTheme.gray60)
          .font(AppTheme.Pretendard.body2.font)
      )
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

  private var resultsHeader: some View {
    HStack {
      Text("사용자")
        .pretendard(.body3Bold)
        .foregroundStyle(AppTheme.gray30)
      Spacer()
      Text("\(store.results.count)명")
        .pretendard(.body3)
        .foregroundStyle(AppTheme.gray60)
    }
    .padding(.horizontal, 20)
    .padding(.bottom, 8)
  }

  // MARK: - Content states

  @ViewBuilder
  private var content: some View {
    if store.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      placeholderView
    } else if store.isLoading && store.results.isEmpty {
      loadingView
    } else if store.hasSearched && store.results.isEmpty {
      emptyView
    } else {
      list
    }
  }

  private var placeholderView: some View {
    VStack(spacing: 12) {
      Image(systemName: "magnifyingglass")
        .font(AppTheme.symbol(size: 44, weight: .light))
        .foregroundStyle(AppTheme.gray60)
      Text("닉네임을 검색하세요")
        .pretendard(.body1)
        .foregroundStyle(.white)
      Text("관심 있는 작가를 찾아 대화를 시작해 보세요")
        .pretendard(.body3)
        .foregroundStyle(AppTheme.gray60)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var loadingView: some View {
    VStack(spacing: 12) {
      ProgressView()
        .progressViewStyle(.circular)
        .tint(AppTheme.gray45)
      Text("검색 중...")
        .pretendard(.body2)
        .foregroundStyle(AppTheme.gray60)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var emptyView: some View {
    VStack(spacing: 12) {
      Image(systemName: "person.crop.circle.badge.questionmark")
        .font(AppTheme.symbol(size: 44, weight: .light))
        .foregroundStyle(AppTheme.gray60)
      Text("검색 결과가 없어요")
        .pretendard(.body1)
        .foregroundStyle(.white)
      Text("정확한 닉네임을 입력했는지 확인해 주세요")
        .pretendard(.body3)
        .foregroundStyle(AppTheme.gray60)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var list: some View {
    List {
      ForEach(store.results, id: \.userID) { user in
        ChatSearchUserRowView(
          user: user,
          baseURL: store.baseURL,
          isCreatingRoom: store.isCreatingRoom,
          profileAction: { store.send(.profileTapped(user)) },
          chatAction: { store.send(.userSelected(user)) }
        )
        .listRowBackground(AppTheme.background)
        .listRowSeparatorTint(AppTheme.deepTurquoise)
        .listRowInsets(EdgeInsets())
      }
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .background(AppTheme.background)
  }

  // MARK: - Creating room overlay

  private var creatingOverlay: some View {
    ZStack {
      Color.black.opacity(0.4).ignoresSafeArea()
      VStack(spacing: 12) {
        ProgressView()
          .progressViewStyle(.circular)
          .tint(.white)
        Text("채팅방을 만드는 중...")
          .pretendard(.body2)
          .foregroundStyle(.white)
      }
      .padding(.vertical, 18)
      .padding(.horizontal, 24)
      .background(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(AppTheme.deepTurquoise.opacity(0.95))
      )
    }
    .transition(.opacity)
  }
}

#Preview {
  NavigationStack {
    ChatSearchView(
      store: Store(initialState: ChatSearchFeature.State()) {
        ChatSearchFeature()
      }
    )
  }
  .preferredColorScheme(.dark)
}
