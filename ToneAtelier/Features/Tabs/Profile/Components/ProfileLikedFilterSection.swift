//
//  ProfileLikedFilterSection.swift
//  ToneAtelier
//
//  Created by Codex on 5/1/26.
//

import SwiftUI

struct ProfileLikedFilterSection: View {
  let filters: [LikedFilter]
  let filterAction: (LikedFilter.ID) -> Void
  let viewAllAction: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 0) {
        Text("좋아하는 필터")
          .font(AppTheme.pretendard(size: 16, weight: .bold))
          .foregroundStyle(AppTheme.gray60)

        Spacer(minLength: 0)

        Button(action: viewAllAction) {
          Text("더보기")
            .font(AppTheme.pretendard(size: 14, weight: .bold))
            .foregroundStyle(AppTheme.brightTurquoise)
            .padding(.vertical, 8)
            .padding(.leading, 12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("좋아하는 필터 더보기")
      }

      VStack(spacing: 0) {
        ForEach(Array(filters.prefix(2))) { filter in
          FeedListItemView(
            item: filter.asFeedFilterItem,
            isLikeRequestInFlight: false,
            likeAction: { _ in },
            selectAction: { _ in filterAction(filter.id) }
          )
          .padding(.vertical, 16)
        }
      }
      // 부모의 가로 패딩 20을 상쇄해 FeedListItemView 자체 패딩이 화면 폭 기준으로 동작하도록 한다.
      .padding(.horizontal, -20)
    }
  }
}

private extension LikedFilter {
  var asFeedFilterItem: FeedFilterItem {
    FeedFilterItem(
      id: id,
      title: title,
      author: author,
      category: category,
      description: description,
      likeCount: likeCount,
      isLiked: true,
      imageURL: coverURL
    )
  }
}

#Preview {
  ProfileLikedFilterSection(
    filters: LikedFilter.placeholders,
    filterAction: { _ in },
    viewAllAction: {}
  )
  .padding(20)
  .background(AppTheme.background)
  .preferredColorScheme(.dark)
}
