//
//  ChatSearchView.swift
//  ToneAtelier
//
//  Created by LCH on 4/29/26.
//

import ComposableArchitecture
import SwiftUI

/// 채팅 상대 검색 화면. 닉네임을 입력하면 디바운스 검색 후 결과를 보여주고,
/// 행 탭 시 채팅방 생성 → 부모로 전달.
struct ChatSearchView: View {
  @Bindable var store: StoreOf<ChatSearchFeature>

  var body: some View {
    ZStack {
      AppTheme.background.ignoresSafeArea()

      VStack(spacing: 0) {
        searchField
        Divider()
          .background(AppTheme.deepTurquoise)
        content
      }
    }
    .navigationTitle("새 채팅")
    .navigationBarTitleDisplayMode(.inline)
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
      )
      .textInputAutocapitalization(.never)
      .autocorrectionDisabled()
      .submitLabel(.search)
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
    .background(AppTheme.background)
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
        .font(.system(size: 44, weight: .light))
        .foregroundStyle(AppTheme.gray60)
      Text("닉네임을 검색하세요")
        .font(AppTheme.pretendard(size: 16, weight: .semibold))
        .foregroundStyle(.white)
      Text("관심 있는 작가를 찾아 대화를 시작해 보세요")
        .font(AppTheme.pretendard(size: 13, weight: .regular))
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
        .font(AppTheme.pretendard(size: 14, weight: .regular))
        .foregroundStyle(AppTheme.gray60)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var emptyView: some View {
    VStack(spacing: 12) {
      Image(systemName: "person.crop.circle.badge.questionmark")
        .font(.system(size: 44, weight: .light))
        .foregroundStyle(AppTheme.gray60)
      Text("검색 결과가 없어요")
        .font(AppTheme.pretendard(size: 16, weight: .semibold))
        .foregroundStyle(.white)
      Text("정확한 닉네임을 입력했는지 확인해 주세요")
        .font(AppTheme.pretendard(size: 13, weight: .regular))
        .foregroundStyle(AppTheme.gray60)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var list: some View {
    List {
      ForEach(store.results, id: \.userID) { user in
        Button {
          store.send(.userSelected(user))
        } label: {
          ChatSearchUserRowView(user: user, baseURL: store.baseURL)
        }
        .buttonStyle(.plain)
        .disabled(store.isCreatingRoom)
        .accessibilityElement(children: .combine)
        .accessibilityHint("채팅 시작")
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
          .font(AppTheme.pretendard(size: 14, weight: .regular))
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
