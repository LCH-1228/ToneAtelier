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
    .navigationDestination(isPresented: presented(\.detail, dismiss: .detailDismissed)) {
      if let detailStore = store.scope(state: \.detail, action: \.detail) {
        HomeDetailView(store: detailStore)
      }
    }
  }

  private func presented<Child>(
    _ keyPath: KeyPath<LikedFiltersFeature.State, Child?>,
    dismiss: LikedFiltersFeature.Action
  ) -> Binding<Bool> {
    Binding(
      get: { store.state[keyPath: keyPath] != nil },
      set: { isPresented in
        if !isPresented {
          store.send(dismiss)
        }
      }
    )
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
              isLikeRequestInFlight: store.likeRequestInFlightIDs.contains(item.id),
              likeAction: { id in store.send(.likeButtonTapped(id)) },
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
        .pretendard(.body2)
        .foregroundStyle(AppTheme.gray60)
      Spacer()
    }
  }

  private var emptyView: some View {
    VStack(spacing: 8) {
      Text("좋아하는 필터가 아직 없어요.")
        .pretendard(.body1)
        .foregroundStyle(AppTheme.gray45)
      Text("마음에 드는 필터에 좋아요를 눌러 보세요.")
        .pretendard(.body3)
        .foregroundStyle(AppTheme.gray60)
    }
    .frame(maxWidth: .infinity)
  }

  private var loadingView: some View {
    VStack(spacing: 18) {
      ProgressView()
        .tint(AppTheme.gray45)
      Text("좋아하는 필터를 불러오는 중입니다.")
        .pretendard(.body2)
        .foregroundStyle(AppTheme.gray60)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func retryView(message: String) -> some View {
    VStack(spacing: 14) {
      Text(message)
        .pretendard(.body2)
        .foregroundStyle(AppTheme.gray60)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 32)

      Button("다시 시도") {
        store.send(.retryButtonTapped)
      }
      .pretendard(.body2)
      .foregroundStyle(AppTheme.gray45)
      .frame(height: 40)
      .padding(.horizontal, 20)
      .background(AppTheme.deepTurquoise)
      .clipShape(Capsule())
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
      isLiked: isLiked,
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
