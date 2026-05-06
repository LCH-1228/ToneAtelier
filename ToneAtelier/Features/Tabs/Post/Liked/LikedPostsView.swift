//
//  LikedPostsView.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//
//  Pencil node: Ah13k (Liked Posts View) + YubvT (Liked Posts Empty View)
//

import ComposableArchitecture
import SwiftUI

struct LikedPostsView: View {
  @Bindable var store: StoreOf<LikedPostsFeature>

  var body: some View {
    Group {
      if store.isFirstLoading && store.posts.isEmpty {
        ProgressView()
          .tint(AppTheme.gray45)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if store.hasLoadedOnce && store.posts.isEmpty {
        LikedPostsEmptyContentView {
          store.send(.exploreTapped)
        }
      } else {
        content
      }
    }
    .background(AppTheme.background.ignoresSafeArea())
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(AppTheme.background, for: .navigationBar)
    .toolbarColorScheme(.dark, for: .navigationBar)
    .toolbar {
      PrincipalToolbarTitle("LIKED")
    }
    .task { store.send(.task) }
  }

  private var content: some View {
    ScrollView {
      LazyVStack(spacing: 16) {
        LikedPostsSummaryView(
          title: "내가 좋아요한 게시글",
          subtitle: "카테고리별로 모아보고, 좋아요 취소 시 목록에서 제거"
        )
        .padding(.horizontal, 20)
        .padding(.top, 12)

        ForEach(store.posts, id: \.postID) { post in
          PostCardView(
            post: post,
            isOwn: false,
            cardAction: {
              store.send(.cardTapped(postID: post.postID))
            },
            likeAction: {},
            authorAction: {},
            editAction: {},
            deleteAction: {}
          )
          .padding(.horizontal, 20)
          .onAppear {
            if post.postID == store.posts.last?.postID {
              store.send(.lastCardAppeared(postID: post.postID))
            }
          }
        }

        if store.isPaginating {
          PostListPaginationLoaderView(isLoading: true)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }

        if let message = store.errorMessage {
          Text(message)
            .pretendard(.captionBold)
            .foregroundStyle(Color(red: 0.95, green: 0.49, blue: 0.49))
            .padding(.horizontal, 20)
        }

        Spacer(minLength: 32)
      }
      .padding(.bottom, 40)
    }
    .scrollIndicators(.hidden)
  }
}

#Preview {
  NavigationStack {
    LikedPostsView(
      store: Store(initialState: LikedPostsFeature.State()) {
        LikedPostsFeature()
      }
    )
  }
  .preferredColorScheme(.dark)
}
