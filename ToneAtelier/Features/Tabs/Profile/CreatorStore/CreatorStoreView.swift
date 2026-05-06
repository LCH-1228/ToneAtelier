//
//  CreatorStoreView.swift
//  ToneAtelier
//
//  Created by Codex on 5/1/26.
//

import ComposableArchitecture
import SwiftUI

struct CreatorStoreView: View {
  @Bindable var store: StoreOf<CreatorStoreFeature>

  // TODO: 작가 공유 기능 후속 브랜치에서 추가.
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
    .navigationTitle(navigationTitle)
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(AppTheme.background, for: .navigationBar)
    .toolbarColorScheme(.dark, for: .navigationBar)
    .alert($store.scope(state: \.alert, action: \.alert))
  }

  private var navigationTitle: String {
    store.headerName ?? store.hero?.nickname ?? "작품"
  }

  private var contentView: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 18) {
        if let hero = store.hero {
          CreatorStoreHeroCard(hero: hero)
            .padding(.horizontal, 20)
        }

        CreatorStoreFilterTabs(selected: store.selectedTab) { tab in
          store.send(.tabSelected(tab))
        }
        .padding(.horizontal, 20)

        if store.items.isEmpty {
          emptyView
            .padding(.top, 40)
        } else {
          VStack(spacing: 0) {
            ForEach(store.sortedItems) { item in
              FeedListItemView(
                item: item.asFeedFilterItem,
                isLikeRequestInFlight: store.likeRequestInFlightIDs.contains(item.id),
                likeAction: { id in store.send(.likeButtonTapped(id)) },
                selectAction: { id in store.send(.rowTapped(id)) }
              )
              .padding(.vertical, 16)
              .contextMenu {
                if store.isOwn {
                  Button(role: .destructive) {
                    store.send(.deleteButtonTapped(item.id))
                  } label: {
                    Label("삭제", systemImage: "trash")
                  }
                }
              }
            }
          }
        }

        if store.isOwn {
          createFilterCTA
            .padding(.horizontal, 20)
            .padding(.top, 4)
        }
      }
      .padding(.top, 16)
      .padding(.bottom, 32)
    }
    .scrollIndicators(.hidden)
  }

  private var createFilterCTA: some View {
    Button {
      store.send(.createFilterButtonTapped)
    } label: {
      HStack(spacing: 8) {
        Image(systemName: "plus")
          .font(AppTheme.symbol(size: 16, weight: .bold))
          .foregroundStyle(AppTheme.gray30)

        Text("새 작품 등록")
          .pretendard(.body2)
          .foregroundStyle(AppTheme.gray30)
      }
      .frame(maxWidth: .infinity)
      .frame(height: 48)
      .background(AppTheme.brightTurquoise)
      .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    .buttonStyle(.plain)
    .accessibilityLabel("새 작품 등록")
  }

  private var emptyView: some View {
    VStack(spacing: 8) {
      Text("등록된 작품이 아직 없어요.")
        .pretendard(.body1)
        .foregroundStyle(AppTheme.gray45)
      Text(store.isOwn ? "첫 작품을 등록해 모음을 채워 보세요." : "곧 새로운 작품이 올라올 거예요.")
        .pretendard(.body3)
        .foregroundStyle(AppTheme.gray60)
    }
    .frame(maxWidth: .infinity)
  }

  private var loadingView: some View {
    VStack(spacing: 18) {
      ProgressView()
        .tint(AppTheme.gray45)
      Text("작품을 불러오는 중입니다.")
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

private extension CreatorStoreItem {
  /// FeedListItemView 재사용을 위한 변환. 단위 3 LikedFilter.asFeedFilterItem과 동일 패턴.
  var asFeedFilterItem: FeedFilterItem {
    FeedFilterItem(
      id: id,
      title: title,
      author: author,
      category: category,
      description: description,
      likeCount: likeCount,
      isLiked: isLiked,
      imageURL: imageURL
    )
  }
}

#Preview {
  let previewItems = [
    CreatorStoreItem(
      id: "store-1",
      title: "청연",
      author: "YOON SESAC",
      authorUserID: "preview-user",
      category: "인물",
      description: "푸르른 여운처럼 마음에 스며드는, 고요하고 깊은 감성의 청록빛 필터.",
      likeCount: 12400,
      imageURL: nil,
      price: 2900,
      createdAt: nil,
      isLiked: false
    ),
    CreatorStoreItem(
      id: "store-2",
      title: "야간",
      author: "YOON SESAC",
      authorUserID: "preview-user",
      category: "야경",
      description: "도시의 밤을 깊고 차분하게 잡아내는 시그니처 톤.",
      likeCount: 8200,
      imageURL: nil,
      price: nil,
      createdAt: nil,
      isLiked: true
    )
  ]

  var previewState = CreatorStoreFeature.State(
    userID: "preview-user",
    isOwn: true,
    headerName: "청록 새록"
  )
  previewState.hero = CreatorStoreHero(
    nickname: "청록 새록",
    name: "YOON SESAC",
    introduction: "자연광과 인물 톤을 중심으로 한 감성 프리셋 작품",
    profileImageURL: nil,
    filterCount: previewItems.count
  )
  previewState.items = previewItems
  previewState.hasLoaded = true

  return NavigationStack {
    CreatorStoreView(
      store: Store(initialState: previewState) {
        CreatorStoreFeature()
      }
    )
  }
  .preferredColorScheme(.dark)
}
