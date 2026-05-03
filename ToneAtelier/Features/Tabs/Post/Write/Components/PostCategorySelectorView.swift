//
//  PostCategorySelectorView.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//
//  Pencil node: G0gta (Post Category Selector)
//

import SwiftUI

struct PostCategorySelectorView: View {
  let selected: PostCategory?
  let onSelect: (PostCategory) -> Void

  var body: some View {
    HStack(spacing: 12) {
      ForEach(PostCategory.allCases, id: \.self) { category in
        chip(category: category, isSelected: selected == category)
      }
    }
    .frame(maxWidth: .infinity, alignment: .center)
  }

  private func chip(category: PostCategory, isSelected: Bool) -> some View {
    Button {
      onSelect(category)
    } label: {
      VStack(spacing: 2) {
        ZStack {
          Circle()
            .fill(AppTheme.gray75.opacity(isSelected ? 0.95 : 0.5))
            .frame(width: 56, height: 56)
          Image(systemName: category.iconSystemName)
            .font(AppTheme.symbol(size: 20, weight: .regular))
            .foregroundStyle(isSelected ? AppTheme.background : AppTheme.gray30)
        }

        Text(category.displayName)
          .font(AppTheme.pretendard(size: 10, weight: .semibold))
          .foregroundStyle(isSelected ? AppTheme.gray30 : AppTheme.gray60)
      }
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(category.displayName) 카테고리")
    .accessibilityAddTraits(isSelected ? .isSelected : [])
    .accessibilityIdentifier("post_category_chip_\(category.rawValue)")
  }
}
