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
    ZStack {
      AppTheme.background.ignoresSafeArea()

      VStack(spacing: 0) {
        headerBar
        searchBox
        content
      }
    }
    .toolbar(.hidden, for: .navigationBar)
    .task {
      isQueryFocused = true
    }
  }

  private var headerBar: some View {
    HStack(spacing: 0) {
      Button {
        store.send(.closeTapped)
      } label: {
        Image(systemName: "chevron.left")
          .font(AppTheme.symbol(size: 18, weight: .regular))
          .foregroundStyle(AppTheme.gray60)
          .frame(width: 44, height: 44)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("뒤로")
      .accessibilityIdentifier("post_search_back_button")

      Spacer(minLength: 0)

      Text("SEARCH")
        .font(AppTheme.mulgyeol(size: 21, weight: .bold))
        .foregroundStyle(AppTheme.gray60)
        .accessibilityIdentifier("post_search_header_title")

      Spacer(minLength: 0)

      Color.clear.frame(width: 44, height: 44)
    }
    .frame(height: 56)
    .padding(.horizontal, 8)
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
      .font(AppTheme.pretendard(size: 13, weight: .bold))
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
        suggestedKeywords: PostSearchFeature.suggestedKeywords,
        errorMessage: nil,
        onSuggestionTap: { keyword in
          store.send(.suggestKeywordTapped(keyword))
        },
        onRetryTap: { store.send(.emptyRetryTapped) }
      )
      .frame(maxHeight: .infinity)

    case .loading:
      VStack(spacing: 12) {
        ProgressView().tint(AppTheme.gray45)
        Text("검색 중입니다...")
          .font(AppTheme.pretendard(size: 13, weight: .medium))
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
        onRetryTap: { store.send(.emptyRetryTapped) }
      )
      .frame(maxHeight: .infinity)
    }
  }

  private var resultsList: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        Text("검색 결과")
          .font(AppTheme.pretendard(size: 14, weight: .bold))
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
