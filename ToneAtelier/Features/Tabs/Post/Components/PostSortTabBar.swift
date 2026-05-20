//
//  PostSortTabBar.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//
//  Pencil node: LB5cB (Post 정렬 탭 바)
//

import SwiftUI

struct PostSortTabBar: View {
  let selected: PostListOrder
  let action: (PostListOrder) -> Void

  var body: some View {
    HStack(spacing: 8) {
      ForEach(PostListOrder.allCases, id: \.self) { order in
        SharedSelectableChipButton(
          title: order.displayName,
          isSelected: selected == order,
          action: { action(order) }
        )
        .accessibilityIdentifier("post_sort_chip_\(order.rawValue)")
      }
      Spacer(minLength: 0)
    }
  }
}

#Preview {
  PostSortTabBar(selected: .createdAt, action: { _ in })
    .padding(20)
    .background(AppTheme.background)
    .preferredColorScheme(.dark)
}
