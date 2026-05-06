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
    NavigationStack(
      path: $store.scope(state: \.path, action: \.path)
    ) {
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
      .background(AppTheme.background.ignoresSafeArea())
      .navigationBarTitleDisplayMode(.inline)
      .toolbarBackground(AppTheme.background, for: .navigationBar)
      .toolbarColorScheme(.dark, for: .navigationBar)
      .toolbar {
        ToolbarItem(placement: .principal) {
          Text("PROFILE")
            .mulgyeol(.bodyNormal)
            .foregroundStyle(AppTheme.gray60)
        }
        PlainToolbarItem(placement: .topBarTrailing) {
          Button {
            store.send(.settingsButtonTapped)
          } label: {
            Image(AppAsset.Profile.settings)
              .renderingMode(.template)
              .resizable()
              .scaledToFit()
              .frame(width: 22, height: 22)
              .foregroundStyle(Color.white)
              .frame(width: 44, height: 44)
              .contentShape(.rect)
          }
          .accessibilityLabel("설정")
        }
      }
    } destination: { store in
      switch store.case {
      case let .detail(store):
        HomeDetailView(store: store)
      case let .likedFiltersList(store):
        LikedFiltersView(store: store)
      case let .creatorStore(store):
        CreatorStoreView(store: store)
      case let .makeView(store):
        MakeView(store: store)
      case let .userPostsList(store):
        UserPostsView(store: store)
      case let .likedPostsList(store):
        LikedPostsView(store: store)
      case let .editProfile(store):
        ProfileEditView(store: store)
      case let .preference(store):
        PreferenceView(store: store)
      case let .postDetail(store):
        PostDetailView(store: store)
      case let .userProfile(store):
        UserProfileView(store: store)
      }
    }
  }

  private var contentView: some View {
    ScrollView {
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
      .padding(.bottom, 32)
    }
    .scrollIndicators(.hidden)
  }

  private var loadingView: some View {
    VStack(spacing: 18) {
      ProgressView()
        .tint(AppTheme.gray45)
      Text("마이 화면을 불러오는 중입니다.")
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
          .pretendard(.body3Bold)
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
  ProfileView(
    store: Store(initialState: ProfileFeature.State()) {
      ProfileFeature()
    }
  )
  .preferredColorScheme(.dark)
}
