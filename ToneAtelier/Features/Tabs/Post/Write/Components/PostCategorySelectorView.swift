//
//  PostCategorySelectorView.swift
//  ToneAtelier
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
        Image(category.assetName)
          .renderingMode(.template)
          .resizable()
          .scaledToFit()
          .foregroundStyle(isSelected ? AppTheme.gray30 : AppTheme.background)
          .frame(width: 32, height: 32)

        Text(category.displayName)
          .pretendard(.caption2Bold)
          .foregroundStyle(isSelected ? AppTheme.gray30 : AppTheme.gray60)
      }
      .frame(width: 56, height: 56)
      .background(isSelected ? AppTheme.brightTurquoise : AppTheme.tabBarBackground)
      .overlay {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .stroke(
            isSelected ? AppTheme.brightTurquoise : AppTheme.gray75.opacity(0.5),
            lineWidth: isSelected ? 2 : 1
          )
      }
      .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(category.displayName) 카테고리")
    .accessibilityAddTraits(isSelected ? .isSelected : [])
    .accessibilityIdentifier("post_category_chip_\(category.rawValue)")
  }
}
