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
    .navigationDestination(isPresented: presented(\.detail, dismiss: .detailDismissed)) {
      if let detailStore = store.scope(state: \.detail, action: \.detail) {
        HomeDetailView(store: detailStore)
      }
    }
    .navigationDestination(isPresented: presented(\.likedFiltersList, dismiss: .likedFiltersListDismissed)) {
      if let listStore = store.scope(state: \.likedFiltersList, action: \.likedFiltersList) {
        LikedFiltersView(store: listStore)
      }
    }
    .navigationDestination(isPresented: presented(\.creatorStore, dismiss: .creatorStoreDismissed)) {
      if let storeScope = store.scope(state: \.creatorStore, action: \.creatorStore) {
        CreatorStoreView(store: storeScope)
      }
    }
    .navigationDestination(isPresented: presented(\.editProfile, dismiss: .editProfileDismissed)) {
      if let editStore = store.scope(state: \.editProfile, action: \.editProfile) {
        ProfileEditView(store: editStore)
      }
    }
    .navigationDestination(isPresented: presented(\.preference, dismiss: .preferenceDismissed)) {
      if let preferenceStore = store.scope(state: \.preference, action: \.preference) {
        PreferenceView(store: preferenceStore)
      }
    }
    .navigationDestination(isPresented: presented(\.makeView, dismiss: .makeViewDismissed)) {
      if let makeStore = store.scope(state: \.makeView, action: \.makeView) {
        MakeView(store: makeStore)
      }
    }
    .navigationDestination(isPresented: presented(\.postDetail, dismiss: .postDetailDismissed)) {
      if let detailStore = store.scope(state: \.postDetail, action: \.postDetail) {
        PostDetailView(store: detailStore)
      }
    }
    .navigationDestination(isPresented: presented(\.userPostsList, dismiss: .userPostsListDismissed)) {
      if let userPostsStore = store.scope(state: \.userPostsList, action: \.userPostsList) {
        UserPostsView(store: userPostsStore)
      }
    }
    .navigationDestination(isPresented: presented(\.likedPostsList, dismiss: .likedPostsListDismissed)) {
      if let likedStore = store.scope(state: \.likedPostsList, action: \.likedPostsList) {
        LikedPostsView(store: likedStore)
      }
    }
    .background(AppTheme.background.ignoresSafeArea())
    .navigationTitle("프로필")
    .toolbar(.hidden, for: .navigationBar)
  }

  private func presented<Child>(
    _ keyPath: KeyPath<ProfileFeature.State, Child?>,
    dismiss: ProfileFeature.Action
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
      VStack(spacing: 0) {
        ProfileHeaderView {
          store.send(.settingsButtonTapped)
        }

        VStack(alignment: .leading, spacing: 16) {
          ProfileSummaryCard(summary: store.summary)

          ProfileActionRow(
            editAction: { store.send(.editProfileButtonTapped) },
            storeAction: { store.send(.creatorStoreButtonTapped) }
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

          ProfilePostNavigationRow(
            iconName: "doc.text",
            title: "내가 쓴 게시글",
            isEnabled: store.currentUserID != nil
          ) {
            store.send(.userPostsTapped)
          }
          .accessibilityIdentifier("profile_my_posts_row")

          ProfilePostNavigationRow(
            iconName: "heart",
            title: "좋아요한 게시글",
            isEnabled: true
          ) {
            store.send(.likedPostsTapped)
          }
          .accessibilityIdentifier("profile_liked_posts_row")
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

/// "내가 쓴 게시글" / "좋아요한 게시글" 진입 셀. PreferenceRow와 톤을 맞추되 마이 화면 컨텍스트에 맞게 단순화.
private struct ProfilePostNavigationRow: View {
  let iconName: String
  let title: String
  let isEnabled: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: iconName)
          .font(AppTheme.symbol(size: 18, weight: .medium))
          .foregroundStyle(isEnabled ? AppTheme.gray60 : AppTheme.gray75)
          .frame(width: 20)

        Text(title)
          .font(AppTheme.pretendard(size: 13, weight: .bold))
          .foregroundStyle(isEnabled ? AppTheme.gray30 : AppTheme.gray60)

        Spacer(minLength: 0)

        Image(systemName: "chevron.right")
          .font(AppTheme.symbol(size: 16, weight: .medium))
          .foregroundStyle(AppTheme.gray75)
      }
      .padding(.horizontal, 12)
      .frame(height: 44)
      .background(AppTheme.blackTurquoise)
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .disabled(!isEnabled)
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
