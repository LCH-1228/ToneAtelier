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
    MoodCardSection(
      title: "좋아하는 필터",
      items: filters.map { filter in
        MoodCardItem(
          id: filter.id,
          title: filter.title,
          category: filter.category,
          author: filter.author,
          description: filter.description,
          metaText: "좋아요 \(filter.likeCount)",
          imageURL: filter.coverURL
        )
      },
      emptyHeadline: "아직 좋아한 필터가 없어요",
      emptyDescription: "마음에 드는 필터를 좋아요로 저장해 보세요",
      viewAllAction: viewAllAction,
      itemAction: filterAction
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
