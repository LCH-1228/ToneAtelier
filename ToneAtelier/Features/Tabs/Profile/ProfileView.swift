//
//  ProfileView.swift
//  ToneAtelier
//
//  Created by Codex on 5/1/26.
//

import ComposableArchitecture
import SwiftUI

struct ProfileView: View {
  @Bindable var store: StoreOf<ProfileFeature>

  var body: some View {
    Group {
      if store.isLoading && !store.hasLoaded {
        loadingView
      } else if let errorMessage = store.errorMessage, !store.hasLoaded {
        retryView(message: errorMessage)
      } else {
        contentView
      }
    }
    .task {
      await store.send(.task).finish()
    }
    .navigationDestination(isPresented: detailIsPresented) {
      if let detailStore = store.scope(state: \.detail, action: \.detail) {
        HomeDetailView(store: detailStore)
      }
    }
    .background(AppTheme.background.ignoresSafeArea())
    .toolbar(.hidden, for: .navigationBar)
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

  private var contentView: some View {
    ScrollView {
      VStack(spacing: 0) {
        ProfileHeaderView {
          store.send(.settingsButtonTapped)
        }

        VStack(alignment: .leading, spacing: 16) {
          ProfileSummaryCard(summary: store.summary)

          ProfileActionRow(
            editAction: { store.send(.editProfileButtonTapped) },
            shopAction: { store.send(.creatorShopButtonTapped) }
          )

          ProfileFeaturedFilterSection(filter: store.featuredFilter) {
            store.send(.featuredFilterTapped)
          }

          ProfileLikedFilterSection(
            filters: store.likedFilters,
            filterAction: { id in
              store.send(.likedFilterTapped(id))
            },
            viewAllAction: {
              store.send(.viewAllLikesTapped)
            }
          )
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, MainTabBarView.Layout.contentInsetHeight + 32)
      }
    }
    .scrollIndicators(.hidden)
  }

  private var loadingView: some View {
    VStack(spacing: 18) {
      ProgressView()
        .tint(AppTheme.gray45)
      Text("마이 화면을 불러오는 중입니다.")
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
}

#Preview {
  NavigationStack {
    ProfileView(
      store: Store(initialState: ProfileFeature.State()) {
        ProfileFeature()
      }
    )
  }
  .preferredColorScheme(.dark)
}
