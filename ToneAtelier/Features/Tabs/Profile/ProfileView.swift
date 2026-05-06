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
        PrincipalToolbarTitle("PROFILE")
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

        MoodCardSection(
          title: "작성글",
          items: store.userPosts.map { post in
            MoodCardItem(
              id: post.id,
              title: post.title,
              category: post.category,
              author: nil,
              description: post.content,
              metaText: "좋아요 \(post.likeCount)",
              imageURL: post.imageURL
            )
          },
          emptyHeadline: "아직 작성한 게시글이 없어요",
          emptyDescription: "첫 게시글을 등록해 보세요",
          viewAllAction: { store.send(.userPostsTapped) },
          itemAction: { id in store.send(.postMoodCardTapped(id)) }
        )

        MoodCardSection(
          title: "좋아요한 게시글",
          items: store.likedPosts.map { post in
            MoodCardItem(
              id: post.id,
              title: post.title,
              category: post.category,
              author: post.creatorNick,
              description: post.content,
              metaText: "좋아요 \(post.likeCount)",
              imageURL: post.imageURL
            )
          },
          emptyHeadline: "아직 좋아요한 게시글이 없어요",
          emptyDescription: "마음에 드는 게시글에 좋아요를 누르면 여기에 저장됩니다",
          viewAllAction: { store.send(.likedPostsTapped) },
          itemAction: { id in store.send(.postMoodCardTapped(id)) }
        )
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

#Preview {
  ProfileView(
    store: Store(initialState: ProfileFeature.State()) {
      ProfileFeature()
    }
  )
  .preferredColorScheme(.dark)
}
