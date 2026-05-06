//
//  PostSearchView.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//
//  Pencil node: i6cSc (Post Search) + A503F (Post Search Empty)
//

import ComposableArchitecture
import SwiftUI

struct PostSearchView: View {
  @Bindable var store: StoreOf<PostSearchFeature>
  @FocusState private var isQueryFocused: Bool

  var body: some View {
    VStack(spacing: 0) {
      searchBox
      content
    }
    .background(AppTheme.background.ignoresSafeArea())
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(AppTheme.background, for: .navigationBar)
    .toolbarColorScheme(.dark, for: .navigationBar)
    .toolbar {
      ToolbarItem(placement: .principal) {
        Text("SEARCH")
          .mulgyeol(.bodyNormal)
          .foregroundStyle(AppTheme.gray60)
      }
    }
    .task {
      isQueryFocused = true
      store.send(.task)
    }
  }

  private var searchBox: some View {
    HStack(spacing: 8) {
      Image(systemName: "magnifyingglass")
        .font(AppTheme.symbol(size: 16, weight: .regular))
        .foregroundStyle(AppTheme.gray60)

      TextField(
        "게시글 제목 검색",
        text: $store.query
      )
      .pretendard(.body3Bold)
      .foregroundStyle(AppTheme.gray30)
      .tint(AppTheme.gray30)
      .submitLabel(.search)
      .focused($isQueryFocused)
      .accessibilityIdentifier("post_search_query_field")

      if !store.query.isEmpty {
        Button {
          store.send(.queryChanged(""))
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(AppTheme.symbol(size: 16, weight: .regular))
            .foregroundStyle(AppTheme.gray60)
            .frame(width: 24, height: 24)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("검색어 지우기")
      }
    }
    .padding(.horizontal, 14)
    .frame(height: 48)
    .background(AppTheme.blackTurquoise)
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    .padding(.horizontal, 20)
    .padding(.top, 8)
  }

  @ViewBuilder
  private var content: some View {
    switch store.phase {
    case .idle:
      PostSearchEmptyContentView(
        mode: .suggesting,
        suggestedKeywords: store.recents,
        errorMessage: nil,
        onSuggestionTap: { keyword in
          store.send(.suggestKeywordTapped(keyword))
        },
        onClearAll: { store.send(.recentsClearTapped) },
        onRetryTap: { store.send(.emptyRetryTapped) }
      )

    case .loading:
      VStack(spacing: 12) {
        ProgressView().tint(AppTheme.gray45)
        Text("검색 중입니다...")
          .pretendard(.body3)
          .foregroundStyle(AppTheme.gray60)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)

    case .results:
      resultsList

    case .empty:
      PostSearchEmptyContentView(
        mode: .noResults,
        suggestedKeywords: [],
        errorMessage: store.errorMessage,
        onSuggestionTap: { _ in },
        onClearAll: {},
        onRetryTap: { store.send(.emptyRetryTapped) }
      )
      .frame(maxHeight: .infinity)
    }
  }

  private var resultsList: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        Text("검색 결과")
          .pretendard(.body2)
          .foregroundStyle(AppTheme.gray30)
          .padding(.horizontal, 20)
          .padding(.top, 16)

        VStack(spacing: 12) {
          ForEach(store.results, id: \.postID) { post in
            PostSearchResultRowView(post: post) {
              store.send(.resultRowTapped(postID: post.postID))
            }
            .padding(.horizontal, 20)
            .accessibilityIdentifier("post_search_result_\(post.postID)")
          }
        }

        Spacer(minLength: 24)
      }
    }
    .scrollIndicators(.hidden)
  }
}

#Preview {
  NavigationStack {
    PostSearchView(
      store: Store(initialState: PostSearchFeature.State()) {
        PostSearchFeature()
      }
    )
  }
  .preferredColorScheme(.dark)
}
