//
//  PostView.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//
//  Pencil node: b9wDw0 (Post 메인 List)
//

import ComposableArchitecture
import SwiftUI

struct PostView: View {
  @Bindable var store: StoreOf<PostFeature>
  @Environment(\.openURL) private var openURL

  var body: some View {
    NavigationStack(
      path: $store.scope(state: \.path, action: \.path)
    ) {
      content
        .background(AppTheme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
          ToolbarItem(placement: .principal) {
            Text("POST")
              .mulgyeol(.bodyNormal)
              .foregroundStyle(AppTheme.gray60)
              .accessibilityIdentifier("post_header_title")
          }
          PlainToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 4) {
              Button {
                store.send(.searchEntryTapped)
              } label: {
                Image(systemName: "magnifyingglass")
                  .resizable()
                  .scaledToFit()
                  .frame(width: 22, height: 22)
                  .foregroundStyle(Color.white)
                  .frame(width: 44, height: 44)
                  .contentShape(.rect)
              }
              .accessibilityLabel("게시글 검색")

              Button {
                store.send(.writeButtonTapped)
              } label: {
                Image(systemName: AppAsset.Post.write)
                  .resizable()
                  .scaledToFit()
                  .frame(width: 22, height: 22)
                  .foregroundStyle(Color.white)
                  .frame(width: 44, height: 44)
                  .contentShape(.rect)
              }
              .accessibilityLabel("새 게시글 작성")
            }
          }
        }
    } destination: { store in
      switch store.case {
      case let .detail(store):
        PostDetailView(store: store)
      case let .userPostsList(store):
        UserPostsView(store: store)
      case let .write(store):
        PostWriteView(store: store)
      case let .search(store):
        PostSearchView(store: store)
      case let .userProfile(store):
        UserProfileView(store: store)
      }
    }
    .task { store.send(.task) }
  }

  private var content: some View {
    ScrollView {
      VStack(spacing: 16) {
        if store.isLocationDenied {
          PostLocationPermissionBanner {
            if let url = URL(string: "app-settings:") {
              openURL(url)
            }
          }
          .frame(maxWidth: .infinity)
          .accessibilityIdentifier("post_location_permission_banner")
        }

        PostSortTabBar(selected: store.order) { order in
          store.send(.orderTabTapped(order))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("post_sort_tabs")

        if store.isFirstLoading {
          ProgressView()
            .progressViewStyle(.circular)
            .tint(AppTheme.gray45)
            .frame(maxWidth: .infinity)
            .frame(height: 240)
        } else if let message = store.errorMessage, store.posts.isEmpty {
          errorView(message: message)
        } else if store.posts.isEmpty, store.hasLoadedOnce {
          emptyView
        } else {
          postCards
          smallCardSection

          if store.isPaginating {
            PostListPaginationLoaderView(isLoading: true)
              .accessibilityIdentifier("post_pagination_loader")
          }
        }
      }
      .padding(.horizontal, 20)
      .padding(.top, 12)
      .padding(.bottom, 24)
      .containerRelativeFrame(.horizontal)
    }
    .scrollIndicators(.hidden)
    .frame(maxWidth: .infinity)
  }

  private var postCards: some View {
    ForEach(store.posts, id: \.postID) { post in
      PostCardView(
        post: post,
        isOwn: store.currentUserID == post.creator.userID,
        cardAction: { store.send(.cardTapped(postID: post.postID)) },
        likeAction: {
          store.send(.cardLikeToggled(postID: post.postID, currentIsLike: post.isLike))
        },
        authorAction: { store.send(.authorTapped(userID: post.creator.userID)) },
        editAction: { store.send(.cardEditTapped(postID: post.postID)) },
        deleteAction: { store.send(.cardDeleteTapped(postID: post.postID)) }
      )
      .accessibilityIdentifier("post_card_\(post.postID)")
      .onAppear {
        // 마지막 카드 노출 시점에 다음 페이지 로드 트리거. ID 비교는 reducer에서 처리해
        // append/reorder race에서도 안전. (FeedFeature.filterItemAppeared 동일 패턴)
        store.send(.lastCardAppeared(postID: post.postID))
      }
    }
  }

  /// "근처에서 인기 있는 게시글" 영역. Tier 2에서 별도 인기 게시글 API 연동 예정 — 현재 비활성.
  /// 첫 페이지 첫 항목을 그대로 노출하면 PostCard ForEach와 중복되므로 EmptyView로 둔다.
  @ViewBuilder
  private var smallCardSection: some View {
    EmptyView()
    // TODO: Tier 2 - 별도 인기 게시글 API 연동 후 PostSmallCardView 노출 복원.
  }

  private var emptyView: some View {
    VStack(spacing: 8) {
      Image(systemName: "tray")
        .font(AppTheme.symbol(size: 32, weight: .regular))
        .foregroundStyle(AppTheme.gray60)
      Text("아직 주변에 게시글이 없어요")
        .pretendard(.body2)
        .foregroundStyle(AppTheme.gray60)
    }
    .frame(maxWidth: .infinity)
    .frame(height: 240)
  }

  private func errorView(message: String) -> some View {
    VStack(spacing: 12) {
      Image(systemName: "exclamationmark.triangle")
        .font(AppTheme.symbol(size: 28, weight: .regular))
        .foregroundStyle(AppTheme.gray60)
      Text(message)
        .pretendard(.body3)
        .foregroundStyle(AppTheme.gray60)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
    }
    .frame(maxWidth: .infinity)
    .frame(height: 240)
  }
}

#Preview {
  NavigationStack {
    PostView(
      store: Store(initialState: PostFeature.State()) {
        PostFeature()
      }
    )
  }
  .preferredColorScheme(.dark)
}
