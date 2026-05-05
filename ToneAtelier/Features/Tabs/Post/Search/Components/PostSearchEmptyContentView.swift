//
//  PostSearchEmptyContentView.swift
//  ToneAtelier
//

import SwiftUI

struct PostSearchEmptyContentView: View {
  enum Mode: Equatable, Sendable {
    case suggesting
    case noResults
  }

  let mode: Mode
  let suggestedKeywords: [String]
  let errorMessage: String?
  let onSuggestionTap: (String) -> Void
  let onClearAll: () -> Void
  let onRetryTap: () -> Void

  var body: some View {
    switch mode {
    case .suggesting:
      suggestingContent
    case .noResults:
      noResultsContent
    }
  }

  private var suggestingContent: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("최근 검색")
          .pretendard(.body1)
          .foregroundStyle(AppTheme.gray60)

        Spacer(minLength: 0)

        if !suggestedKeywords.isEmpty {
          Button(action: onClearAll) {
            Text("전체 삭제")
              .pretendard(.captionBold)
              .foregroundStyle(AppTheme.gray75)
          }
          .buttonStyle(.plain)
        }
      }

      if suggestedKeywords.isEmpty {
        Text("최근 검색어가 없어요.")
          .pretendard(.captionBold)
          .foregroundStyle(AppTheme.gray75)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.top, 8)
      } else {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            ForEach(suggestedKeywords, id: \.self) { keyword in
              Button {
                onSuggestionTap(keyword)
              } label: {
                Text(keyword)
                  .pretendard(.captionBold)
                  .foregroundStyle(AppTheme.gray30)
                  .padding(.horizontal, 14)
                  .frame(height: 28)
                  .background(AppTheme.blackTurquoise)
                  .overlay {
                    Capsule().stroke(AppTheme.deepTurquoise, lineWidth: 1)
                  }
                  .clipShape(Capsule())
                  .contentShape(.rect)
              }
              .buttonStyle(.plain)
              .accessibilityIdentifier("post_search_suggest_\(keyword)")
            }
          }
        }
      }
    }
    .padding(.horizontal, 20)
    .padding(.top, 16)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private var noResultsContent: some View {
    VStack(spacing: 14) {
      Spacer(minLength: 0)

      ZStack {
        Circle()
          .fill(AppTheme.blackTurquoise)
          .frame(width: 96, height: 96)
        Image(systemName: "magnifyingglass")
          .font(.system(size: 36, weight: .regular))
          .foregroundStyle(AppTheme.brightTurquoise)
          .overlay(alignment: .topTrailing) {
            Image(systemName: "xmark")
              .font(.system(size: 16, weight: .bold))
              .foregroundStyle(AppTheme.brightTurquoise)
              .offset(x: 6, y: -6)
          }
      }

      Text("검색 결과가 없어요")
        .mulgyeol(.pageTitle)
        .foregroundStyle(AppTheme.gray30)

      Text("입력한 제목과 일치하는 게시글을 찾지 못했어요.\n다른 키워드로 다시 검색해보세요.")
        .pretendard(.body3Bold)
        .foregroundStyle(AppTheme.gray60)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 32)

      if let errorMessage {
        Text(errorMessage)
          .pretendard(.caption1)
          .foregroundStyle(Color(red: 0.95, green: 0.49, blue: 0.49))
          .multilineTextAlignment(.center)
          .padding(.horizontal, 32)
      }

      Spacer(minLength: 0)

      Button(action: onRetryTap) {
        Text("검색어 다시 입력")
          .pretendard(.body2)
          .foregroundStyle(AppTheme.gray30)
          .frame(maxWidth: .infinity)
          .frame(height: 48)
          .background(AppTheme.brightTurquoise)
          .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .padding(.horizontal, 20)
      .padding(.bottom, 24)
      .accessibilityIdentifier("post_search_retry_button")
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
