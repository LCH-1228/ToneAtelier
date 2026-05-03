//
//  UserPostsView.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//
//  Pencil node: hIud2 (User Posts View) + r4DND (Unknown User State View)
//

import ComposableArchitecture
import SwiftUI

struct UserPostsView: View {
  @Bindable var store: StoreOf<UserPostsFeature>

  var body: some View {
    ZStack {
      AppTheme.background.ignoresSafeArea()

      VStack(spacing: 0) {
        headerBar

        Group {
          if store.isUnknownUser {
            UserPostsUnknownStateView(
              onRetryTap: { store.send(.retryTapped) },
              onBackToListTap: { store.send(.backToListTapped) }
            )
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
      .accessibilityIdentifier("user_posts_back_button")

      Spacer(minLength: 0)

      Text("USER POSTS")
        .font(AppTheme.mulgyeol(size: 21, weight: .bold))
        .foregroundStyle(AppTheme.gray60)
        .accessibilityIdentifier("user_posts_header_title")

      Spacer(minLength: 0)

      Color.clear.frame(width: 44, height: 44)
    }
    .frame(height: 56)
    .padding(.horizontal, 8)
  }

  @ViewBuilder
  private var content: some View {
    ScrollView {
      VStack(spacing: 16) {
        UserPostsHeaderView(
          nickname: headerNickname,
          introduction: store.profile?.introduction,
          profileImagePath: store.profile?.profileImage,
          hashTags: store.profile?.hashTags ?? [],
          onProfileTap: {}
        )
        .padding(.horizontal, 20)
        .padding(.top, 12)

        UserPostsCategoryTabsView(
          selected: store.selectedCategory,
          onTap: { category in
            store.send(.categoryTapped(category))
          }
        )

        if store.isFirstLoading && store.posts.isEmpty {
          ProgressView()
            .tint(AppTheme.gray45)
            .padding(.top, 40)
        } else if store.posts.isEmpty {
          emptyState
        } else {
          UserPostsGridView(
            posts: store.posts,
            isPaginating: store.isPaginating,
            onCardTap: { postID in
              store.send(.cardTapped(postID: postID))
            },
            onLastCardAppear: { postID in
              store.send(.lastCardAppeared(postID: postID))
            }
          )
          .padding(.horizontal, 20)
        }

        if let message = store.errorMessage {
          Text(message)
            .font(AppTheme.pretendard(size: 12, weight: .semibold))
            .foregroundStyle(Color(red: 0.95, green: 0.49, blue: 0.49))
            .padding(.horizontal, 20)
        }

        Spacer(minLength: 32)
      }
      .padding(.bottom, 40)
    }
    .scrollIndicators(.hidden)
  }

  private var emptyState: some View {
    VStack(spacing: 8) {
      Image(systemName: "tray")
        .font(AppTheme.symbol(size: 28, weight: .regular))
        .foregroundStyle(AppTheme.gray75)
      Text("작성한 게시글이 없어요")
        .font(AppTheme.pretendard(size: 13, weight: .bold))
        .foregroundStyle(AppTheme.gray60)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 48)
  }

  private var headerNickname: String {
    if let profileNickname = store.profile?.nickname, !profileNickname.isEmpty {
      return profileNickname
    }
    if let header = store.headerNickname, !header.isEmpty {
      return header
    }
    return "사용자"
  }
}

#Preview {
  NavigationStack {
    UserPostsView(
      store: Store(initialState: UserPostsFeature.State(userID: "preview", headerNickname: "윤새싹")) {
        UserPostsFeature()
      }
    )
  }
  .preferredColorScheme(.dark)
}
