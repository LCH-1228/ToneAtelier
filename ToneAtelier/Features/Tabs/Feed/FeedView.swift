//
//  FeedView.swift
//  ToneAtelier
//
//  Created by Codex on 4/25/26.
//

import ComposableArchitecture
import SwiftUI

struct FeedView: View {
  @Bindable var store: StoreOf<FeedFeature>
  var backAction: (() -> Void)?

  init(
    store: StoreOf<FeedFeature>,
    backAction: (() -> Void)? = nil
  ) {
    self.store = store
    self.backAction = backAction
  }

  var body: some View {
    NavigationStack(
      path: $store.scope(state: \.path, action: \.path)
    ) {
      rootContent
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
          if let backAction {
            PlainToolbarItem(placement: .topBarLeading) {
              Button(action: backAction) {
                Image(systemName: "chevron.left")
                  .resizable()
                  .scaledToFit()
                  .frame(width: 22, height: 22)
                  .foregroundStyle(Color.white)
                  .frame(width: 44, height: 44)
                  .contentShape(.rect)
              }
              .accessibilityLabel("뒤로 가기")
            }
          }
          PrincipalToolbarTitle("FEED")
          PlainToolbarItem(placement: .topBarTrailing) {
            Button {
              store.send(.makeButtonTapped)
            } label: {
              Image(systemName: AppAsset.Make.write)
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
                .foregroundStyle(Color.white)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
            }
            .accessibilityLabel("필터 만들기")
          }
        }
    } destination: { store in
      switch store.case {
      case let .detail(store):
        HomeDetailView(store: store)
      case let .userProfile(store):
        UserProfileView(store: store)
      case let .creatorStore(store):
        CreatorStoreView(store: store)
      case let .makeView(store):
        MakeView(store: store)
      }
    }
  }

  private var rootContent: some View {
    GeometryReader { proxy in
      let contentWidth = proxy.size.width

      ZStack(alignment: .top) {
        AppTheme.background
          .ignoresSafeArea()

        ScrollView(showsIndicators: false) {
          VStack(spacing: 0) {
            FeedSectionTitle(title: "Top Ranking")
              .frame(height: 59)

            FeedSortButtonRow(
              selectedOption: store.sortOption,
              isDisabled: store.isLoading,
              selectAction: { option in
                store.send(.sortOptionTapped(option), animation: .easeInOut(duration: 0.18))
              }
            )
              .frame(height: 44)

            Color.clear
              .frame(height: 24)

            FeedRankingCarousel(
              items: store.rankingItems,
              focusedID: store.resolvedFocusedRankingID,
              selectAction: { id in
                store.send(.rankingCardTapped(id), animation: .easeInOut(duration: 0.3))
              },
              focusAction: { id in
                store.send(.rankingScrollPositionChanged(id))
              }
            )
              .frame(height: 474)

            Color.clear
              .frame(height: 16)

            FeedModeHeader(displayMode: store.displayMode) {
              store.send(.displayModeButtonTapped, animation: .easeInOut(duration: 0.18))
            }
              .frame(height: 59)

            Group {
              switch store.displayMode {
              case .list:
                FeedListLayout(
                  items: store.filterItems,
                  isLoading: store.isLoading || store.isLoadingFilterFeed,
                  isLoadingNextPage: store.isLoadingNextPage,
                  errorMessage: store.filterFeedErrorMessage ?? store.errorMessage,
                  nextPageErrorMessage: store.nextPageErrorMessage,
                  canLoadNextPage: store.canLoadNextPage,
                  likingFilterIDs: store.likingFilterIDs,
                  itemAppearAction: { id in
                    store.send(.filterItemAppeared(id))
                  },
                  likeAction: { id in
                    store.send(.filterLikeButtonTapped(id), animation: .easeInOut(duration: 0.18))
                  },
                  selectAction: { id in
                    store.send(.filterCardTapped(id))
                  },
                  refreshAction: {
                    if store.filterFeedErrorMessage == nil {
                      store.send(.refreshButtonTapped)
                    } else {
                      store.send(.filterFeedRetryButtonTapped)
                    }
                  },
                  nextPageRetryAction: {
                    store.send(.nextPageRetryButtonTapped)
                  }
                )
              case .block:
                FeedBlockLayout(
                  availableWidth: contentWidth,
                  items: store.filterItems,
                  isLoading: store.isLoading || store.isLoadingFilterFeed,
                  isLoadingNextPage: store.isLoadingNextPage,
                  errorMessage: store.filterFeedErrorMessage ?? store.errorMessage,
                  nextPageErrorMessage: store.nextPageErrorMessage,
                  canLoadNextPage: store.canLoadNextPage,
                  likingFilterIDs: store.likingFilterIDs,
                  itemAppearAction: { id in
                    store.send(.filterItemAppeared(id))
                  },
                  likeAction: { id in
                    store.send(.filterLikeButtonTapped(id), animation: .easeInOut(duration: 0.18))
                  },
                  selectAction: { id in
                    store.send(.filterCardTapped(id))
                  },
                  refreshAction: {
                    if store.filterFeedErrorMessage == nil {
                      store.send(.refreshButtonTapped)
                    } else {
                      store.send(.filterFeedRetryButtonTapped)
                    }
                  },
                  nextPageRetryAction: {
                    store.send(.nextPageRetryButtonTapped)
                  }
                )
              }
            }

            Color.clear
              .frame(height: 32)
          }
          .frame(width: contentWidth)
        }
      }
    }
    .background(AppTheme.background.ignoresSafeArea())
    .preferredColorScheme(.dark)
    .gesture(
      // cross-tab 진입 시 leftEdge swipe → Home 직행.
      // backAction 이 nil 이면 noop. NavigationStack 자동 swipe back 은 cross-tab 에 무효.
      DragGesture(minimumDistance: 20, coordinateSpace: .local)
        .onEnded { value in
          guard let backAction else { return }
          if value.startLocation.x < 24 && value.translation.width > 80 {
            backAction()
          }
        }
    )
    .task {
      await store.send(.task).finish()
    }
  }
}

#Preview {
  NavigationStack {
    FeedView(
      store: Store(
        initialState: FeedFeature.State(category: .food)
      ) {
        FeedFeature()
      }
    )
  }
}
