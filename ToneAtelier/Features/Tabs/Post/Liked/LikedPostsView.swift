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
    ZStack {
      AppTheme.background.ignoresSafeArea()

      VStack(spacing: 0) {
        headerBar

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
      }
    }
    .toolbar(.hidden, for: .navigationBar)
    .task { store.send(.task) }
  }

  private var headerBar: some View {
    HStack(spacing: 0) {
      Button {
        store.send(.backTapped)
      } label: {
        Image(systemName: "chevron.left")
          .font(AppTheme.symbol(size: 18, weight: .regular))
          .foregroundStyle(AppTheme.gray60)
          .frame(width: 44, height: 44)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("뒤로")
      .accessibilityIdentifier("liked_posts_back_button")

      Spacer(minLength: 0)

      Text("LIKED")
        .mulgyeol(.pageTitle)
        .foregroundStyle(AppTheme.gray60)
        .accessibilityIdentifier("liked_posts_header_title")

      Spacer(minLength: 0)

      Color.clear.frame(width: 44, height: 44)
    }
    .frame(height: 56)
    .padding(.horizontal, 8)
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
