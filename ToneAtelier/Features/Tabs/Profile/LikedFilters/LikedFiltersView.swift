//
//  LikedFiltersView.swift
//  ToneAtelier
//
//  Created by Codex on 5/1/26.
//

import ComposableArchitecture
import SwiftUI

struct LikedFiltersView: View {
  @Bindable var store: StoreOf<LikedFiltersFeature>

  var body: some View {
    Group {
      if store.isLoading && !store.hasLoaded {
        loadingView
      } else if let message = store.errorMessage, !store.hasLoaded {
        retryView(message: message)
      } else {
        contentView
      }
    }
    .task {
      await store.send(.task).finish()
    }
    .background(AppTheme.background.ignoresSafeArea())
    .navigationTitle("좋아하는 필터")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(AppTheme.background, for: .navigationBar)
    .toolbarColorScheme(.dark, for: .navigationBar)
    .navigationDestination(isPresented: detailIsPresented) {
      if let detailStore = store.scope(state: \.detail, action: \.detail) {
        HomeDetailView(store: detailStore)
      }
    }
  }

  private var contentView: some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        // TODO: 후속 브랜치에서 바로 적용·공유 등 Quick Actions 추가.
        countHeader
          .padding(.horizontal, 20)
          .padding(.top, 8)
          .padding(.bottom, 4)

        if store.items.isEmpty {
          emptyView
            .padding(.top, 60)
        } else {
          ForEach(store.items) { item in
            FeedListItemView(
              item: item.asFeedFilterItem,
              isLikeRequestInFlight: false,
              likeAction: { _ in },
              selectAction: { id in store.send(.rowTapped(id)) }
            )
            .padding(.vertical, 16)
          }
        }
      }
      .padding(.bottom, MainTabBarView.Layout.contentInsetHeight + 32)
    }
    .scrollIndicators(.hidden)
  }

  private var countHeader: some View {
    HStack {
      Text("좋아하는 필터 \(store.items.count)개")
        .font(AppTheme.pretendard(size: 14, weight: .semibold))
        .foregroundStyle(AppTheme.gray60)
      Spacer()
    }
  }

  private var emptyView: some View {
    VStack(spacing: 8) {
      Text("좋아하는 필터가 아직 없어요.")
        .font(AppTheme.pretendard(size: 15, weight: .semibold))
        .foregroundStyle(AppTheme.gray45)
      Text("마음에 드는 필터에 좋아요를 눌러 보세요.")
        .font(AppTheme.pretendard(size: 13, weight: .medium))
        .foregroundStyle(AppTheme.gray60)
    }
    .frame(maxWidth: .infinity)
  }

  private var loadingView: some View {
    VStack(spacing: 18) {
      ProgressView()
        .tint(AppTheme.gray45)
      Text("좋아하는 필터를 불러오는 중입니다.")
        .font(AppTheme.pretendard(size: 14, weight: .medium))
        .foregroundStyle(AppTheme.gray60)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func retryView(message: String) -> some View {
    VStack(spacing: 14) {
      Text(message)
        .font(AppTheme.pretendard(size: 14, weight: .medium))
        .foregroundStyle(AppTheme.gray60)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 32)

      Button("다시 시도") {
        store.send(.retryButtonTapped)
      }
      .font(AppTheme.pretendard(size: 14, weight: .bold))
      .foregroundStyle(AppTheme.gray45)
      .frame(height: 40)
      .padding(.horizontal, 20)
      .background(AppTheme.deepTurquoise)
      .clipShape(Capsule())
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var detailIsPresented: Binding<Bool> {
    Binding(
      get: { store.detail != nil },
      set: { isPresented in
        if !isPresented {
          store.send(.detailDismissed)
        }
      }
    )
  }
}

private extension LikedFilter {
  var asFeedFilterItem: FeedFilterItem {
    FeedFilterItem(
      id: id,
      title: title,
      author: author,
      category: category,
      description: description,
      likeCount: likeCount,
      isLiked: true,
      imageURL: coverURL
    )
  }
}

#Preview {
  var previewState = LikedFiltersFeature.State()
  previewState.items = LikedFilter.placeholders
  previewState.hasLoaded = true

  return NavigationStack {
    LikedFiltersView(
      store: Store(initialState: previewState) {
        LikedFiltersFeature()
      }
    )
  }
  .preferredColorScheme(.dark)
}
