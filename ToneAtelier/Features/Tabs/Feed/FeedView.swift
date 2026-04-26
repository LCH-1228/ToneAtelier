//
//  FeedView.swift
//  ToneAtelier
//
//  Created by Codex on 4/25/26.
//

import ComposableArchitecture
import SwiftUI

struct FeedView: View {
  @Environment(\.dismiss) private var dismiss

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
    GeometryReader { proxy in
      let contentWidth = proxy.size.width
      let topSafeAreaInset = max(proxy.safeAreaInsets.top, 44)

      ZStack(alignment: .top) {
        HomeTheme.background
          .ignoresSafeArea()

        ScrollView(showsIndicators: false) {
          VStack(spacing: 0) {
            Color.clear
              .frame(height: topSafeAreaInset + 56)

            FeedSectionTitle(title: "Top Ranking")
              .frame(height: 59)

            FeedSortButtonRow()
              .frame(height: 44)

            Color.clear
              .frame(height: 24)

            FeedRankingCarousel(
              items: store.rankingItems,
              selectAction: { id in
                store.send(.filterCardTapped(id))
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
                  isLoading: store.isLoading,
                  isLoadingNextPage: store.isLoadingNextPage,
                  errorMessage: store.errorMessage,
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
                    store.send(.refreshButtonTapped)
                  },
                  nextPageRetryAction: {
                    store.send(.nextPageRetryButtonTapped)
                  }
                )
              case .block:
                FeedBlockLayout(
                  availableWidth: contentWidth,
                  items: store.filterItems,
                  isLoading: store.isLoading,
                  isLoadingNextPage: store.isLoadingNextPage,
                  errorMessage: store.errorMessage,
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
                    store.send(.refreshButtonTapped)
                  },
                  nextPageRetryAction: {
                    store.send(.nextPageRetryButtonTapped)
                  }
                )
              }
            }
            .padding(.bottom, FeedLayout.tabBarClearance)
          }
          .frame(width: contentWidth)
        }

        FeedNavigationHeader {
          if let backAction {
            backAction()
          } else {
            dismiss()
          }
        }
        .padding(.top, topSafeAreaInset)
        .background(HomeTheme.background.ignoresSafeArea(edges: .top))
      }
    }
    .background(HomeTheme.background.ignoresSafeArea())
    .navigationBarBackButtonHidden(true)
    .toolbar(.hidden, for: .navigationBar)
    .ignoresSafeArea(edges: .top)
    .preferredColorScheme(.dark)
    .task {
      await store.send(.task).finish()
    }
    .navigationDestination(isPresented: detailIsPresented) {
      if let detailStore = store.scope(
        state: \.detail,
        action: \.detail
      ) {
        HomeDetailView(store: detailStore)
      }
    }
  }

  private var detailIsPresented: Binding<Bool> {
    Binding(
      get: {
        store.detail != nil
      },
      set: { isPresented in
        if !isPresented {
          store.send(.detailDismissed)
        }
      }
    )
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
