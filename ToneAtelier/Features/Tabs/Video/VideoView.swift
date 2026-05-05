//
//  VideoView.swift
//  ToneAtelier
//
//  Created by Codex on 5/5/26.
//

import ComposableArchitecture
import SwiftUI

struct VideoView: View {
  @Bindable var store: StoreOf<VideoFeature>
  @FocusState private var isSearchFieldFocused: Bool

  var body: some View {
    content
      .background(AppTheme.background.ignoresSafeArea())
      .toolbar(.hidden, for: .navigationBar)
      .navigationDestination(isPresented: presented(\.detail, dismiss: .detailDismissed)) {
        if let detailStore = store.scope(state: \.detail, action: \.detail) {
          VideoDetailView(store: detailStore)
        }
      }
      .task { store.send(.task) }
  }

  private func presented<Child>(
    _ keyPath: KeyPath<VideoFeature.State, Child?>,
    dismiss: VideoFeature.Action
  ) -> Binding<Bool> {
    Binding(
      get: { store.state[keyPath: keyPath] != nil },
      set: { isPresented in
        if !isPresented { store.send(dismiss) }
      }
    )
  }

  private var content: some View {
    VStack(spacing: 0) {
      headerBar

      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          if store.isFirstLoading {
            loadingState
          } else if let message = store.errorMessage, store.listVideos.isEmpty {
            errorState(message: message)
          } else if store.displayedVideos.isEmpty, store.hasLoadedOnce {
            emptyState
          } else {
            sectionTitle
            cardList
          }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, MainTabBarView.Layout.contentInsetHeight + 24)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .scrollIndicators(.hidden)
    }
    .frame(maxWidth: .infinity)
  }

  // MARK: - Header

  @ViewBuilder
  private var headerBar: some View {
    if store.isSearchActive {
      searchBar
    } else {
      titleBar
    }
  }

  private var titleBar: some View {
    HStack(spacing: 0) {
      Spacer(minLength: 0)
      Text("VIDEO")
        .mulgyeol(.pageTitle)
        .foregroundStyle(AppTheme.gray60)
      Spacer(minLength: 0)
    }
    .frame(height: 56)
    .padding(.horizontal, 20)
    .overlay(alignment: .trailing) {
      Button {
        store.send(.searchToggled)
        isSearchFieldFocused = true
      } label: {
        Image(systemName: "magnifyingglass")
          .font(AppTheme.symbol(size: 20, weight: .regular))
          .foregroundStyle(AppTheme.gray60)
          .frame(width: 44, height: 44)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .padding(.trailing, 12)
      .accessibilityIdentifier("video_search_toggle")
    }
  }

  private var searchBar: some View {
    HStack(spacing: 8) {
      Image(systemName: "magnifyingglass")
        .font(AppTheme.symbol(size: 16, weight: .regular))
        .foregroundStyle(AppTheme.gray60)
      TextField(
        "",
        text: Binding(
          get: { store.searchQuery },
          set: { store.send(.searchQueryChanged($0)) }
        ),
        prompt: Text("영상 제목 검색").foregroundStyle(AppTheme.gray60)
      )
      .pretendard(.body2)
      .foregroundStyle(AppTheme.gray30)
      .focused($isSearchFieldFocused)
      .submitLabel(.search)
      .accessibilityIdentifier("video_search_field")

      Button {
        store.send(.searchToggled)
        isSearchFieldFocused = false
      } label: {
        Image(systemName: "xmark")
          .font(AppTheme.symbol(size: 16, weight: .regular))
          .foregroundStyle(AppTheme.gray60)
          .frame(width: 32, height: 32)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("video_search_close")
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
    .background(AppTheme.deepTurquoise, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .padding(.horizontal, 20)
    .frame(height: 56)
  }

  // MARK: - Sections

  private var sectionTitle: some View {
    Text("추천 영상")
      .pretendard(.body1)
      .foregroundStyle(AppTheme.gray30)
  }

  private var cardList: some View {
    VStack(spacing: 16) {
      ForEach(store.displayedVideos, id: \.videoID) { video in
        VideoListCard(
          video: video,
          watchProgress: store.watchProgresses[video.videoID] ?? 0,
          onTap: { store.send(.cardTapped(videoID: video.videoID)) },
          onLikeTap: { store.send(.cardLikeToggled(videoID: video.videoID)) }
        )
        .onAppear {
          store.send(.lastCardAppeared(videoID: video.videoID))
        }
      }

      if store.isPaginating {
        HStack {
          Spacer()
          ProgressView()
            .progressViewStyle(.circular)
            .tint(AppTheme.gray45)
          Spacer()
        }
        .padding(.vertical, 16)
      }
    }
  }

  // MARK: - Empty / loading / error

  private var loadingState: some View {
    HStack {
      Spacer()
      ProgressView()
        .progressViewStyle(.circular)
        .tint(AppTheme.gray45)
      Spacer()
    }
    .frame(height: 240)
  }

  private var emptyState: some View {
    VStack(spacing: 8) {
      Image(systemName: "tray")
        .font(AppTheme.symbol(size: 32, weight: .regular))
        .foregroundStyle(AppTheme.gray60)
      Text(store.isSearchActive && !store.searchQuery.isEmpty
        ? "검색 결과가 없어요"
        : "아직 영상이 없어요")
        .pretendard(.body2)
        .foregroundStyle(AppTheme.gray60)
    }
    .frame(maxWidth: .infinity)
    .frame(height: 240)
  }

  private func errorState(message: String) -> some View {
    VStack(spacing: 12) {
      Image(systemName: "exclamationmark.triangle")
        .font(AppTheme.symbol(size: 28, weight: .regular))
        .foregroundStyle(AppTheme.gray60)
      Text(message)
        .pretendard(.body3)
        .foregroundStyle(AppTheme.gray60)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
    }
    .frame(maxWidth: .infinity)
    .frame(height: 240)
  }
}

#Preview {
  NavigationStack {
    VideoView(
      store: Store(initialState: VideoFeature.State()) {
        VideoFeature()
      }
    )
  }
  .preferredColorScheme(.dark)
}
