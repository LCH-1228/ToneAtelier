//
//  PostSearchEmptyContentView.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//
//  Pencil node: A503F (Post Search Empty)
//

import SwiftUI

struct PostSearchEmptyContentView: View {
  enum Mode: Equatable, Sendable {
    /// query가 비어 있고 아직 검색 전. 추천 검색어를 노출.
    case suggesting
    /// 검색을 했지만 결과가 0건.
    case noResults
  }

  let mode: Mode
  let suggestedKeywords: [String]
  let errorMessage: String?
  let onSuggestionTap: (String) -> Void
  let onRetryTap: () -> Void

  var body: some View {
    VStack(spacing: 18) {
      illustration

      Text(titleText)
        .font(AppTheme.mulgyeol(size: 22, weight: .bold))
        .foregroundStyle(AppTheme.gray30)
        .multilineTextAlignment(.center)

      Text(descriptionText)
        .font(AppTheme.pretendard(size: 13, weight: .semibold))
        .foregroundStyle(AppTheme.gray60)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 32)

      if let errorMessage {
        Text(errorMessage)
          .font(AppTheme.pretendard(size: 12, weight: .medium))
          .foregroundStyle(Color(red: 0.95, green: 0.49, blue: 0.49))
          .multilineTextAlignment(.center)
          .padding(.horizontal, 32)
      }

      if mode == .suggesting && !suggestedKeywords.isEmpty {
        suggestedRow
      }

      if mode == .noResults {
        retryButton
      }
    }
    .padding(.vertical, 16)
  }

  private var illustration: some View {
    ZStack {
      Circle()
        .fill(AppTheme.blackTurquoise)
        .frame(width: 96, height: 96)
      Image(systemName: mode == .noResults ? "magnifyingglass" : "lightbulb")
        .font(AppTheme.symbol(size: 36, weight: .regular))
        .foregroundStyle(AppTheme.gray60)
    }
  }

  private var titleText: String {
    switch mode {
    case .suggesting: return "검색해 보세요"
    case .noResults: return "검색 결과가 없어요"
    }
  }

  private var descriptionText: String {
    switch mode {
    case .suggesting:
      return "게시글 제목으로 검색할 수 있어요.\n아래 추천 검색어로 시작해 보세요."
    case .noResults:
      return "입력한 제목과 일치하는 게시글을 찾지 못했어요. 다른 키워드로 다시 검색해 보세요."
    }
  }

  private var suggestedRow: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("추천 검색어")
        .font(AppTheme.pretendard(size: 13, weight: .bold))
        .foregroundStyle(AppTheme.gray30)
        .frame(maxWidth: .infinity, alignment: .leading)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(suggestedKeywords, id: \.self) { keyword in
            Button {
              onSuggestionTap(keyword)
            } label: {
              Text(keyword)
                .font(AppTheme.pretendard(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.gray30)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(AppTheme.blackTurquoise)
                .clipShape(Capsule())
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("post_search_suggest_\(keyword)")
          }
        }
      }
    }
    .padding(.horizontal, 20)
    .padding(.top, 8)
  }

  private var retryButton: some View {
    Button(action: onRetryTap) {
      Text("검색어 다시 입력")
        .font(AppTheme.pretendard(size: 14, weight: .bold))
        .foregroundStyle(AppTheme.gray30)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(AppTheme.brightTurquoise)
        .clipShape(Capsule())
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .padding(.horizontal, 20)
    .accessibilityIdentifier("post_search_retry_button")
  }
}
