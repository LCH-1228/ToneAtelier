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
    .background(AppTheme.background.ignoresSafeArea())
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(AppTheme.background, for: .navigationBar)
    .toolbarColorScheme(.dark, for: .navigationBar)
    .toolbar {
      ToolbarItem(placement: .principal) {
        Text("USER POSTS")
          .mulgyeol(.bodyNormal)
          .foregroundStyle(AppTheme.gray60)
          .accessibilityIdentifier("user_posts_header_title")
      }
    }
    .task { store.send(.task) }
  }

  @ViewBuilder
  private var content: some View {
    ScrollView {
      VStack(spacing: 16) {
        UserProfileHeader(
          name: headerNickname,
          subtitle: headerSubtitle,
          profileImageURL: store.profile?.profileImage,
          isSelf: store.isSelf,
          profileAction: { store.send(.profileButtonTapped) },
          messageAction: { store.send(.messageButtonTapped) }
        )
        .padding(14)
        .background(AppTheme.blackTurquoise)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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

  private var emptyState: some View {
    VStack(spacing: 8) {
      Image(systemName: "tray")
        .font(AppTheme.symbol(size: 28, weight: .regular))
        .foregroundStyle(AppTheme.gray75)
      Text("작성한 게시글이 없어요")
        .pretendard(.body3Bold)
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

  private var headerSubtitle: String {
    let trimmedIntro = store.profile?.introduction?.trimmingCharacters(in: .whitespacesAndNewlines)
    if let trimmedIntro, !trimmedIntro.isEmpty {
      return trimmedIntro
    }
    let tags = store.profile?.hashTags ?? []
    if !tags.isEmpty {
      return tags.map { "#\($0)" }.joined(separator: " ")
    }
    return ""
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
