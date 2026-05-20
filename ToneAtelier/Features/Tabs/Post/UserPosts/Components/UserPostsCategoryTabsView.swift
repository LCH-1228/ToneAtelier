//
//  UserPostsCategoryTabsView.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//
//  Pencil node: OwLQh (u_tabs)
//

import SwiftUI

struct UserPostsCategoryTabsView: View {
  let selected: PostCategory?
  let onTap: (PostCategory?) -> Void

  /// "전체"는 nil로 매핑. PostCategory 5종은 enum CaseIterable로 자동 노출.
  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        tab(title: "전체", isSelected: selected == nil) {
          onTap(nil)
        }
        ForEach(PostCategory.allCases, id: \.self) { category in
          tab(title: category.displayName, isSelected: selected == category) {
            onTap(category)
          }
        }
      }
      .padding(.horizontal, 20)
    }
  }

  private func tab(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(title)
        .pretendard(.captionBold)
        .foregroundStyle(isSelected ? AppTheme.gray30 : AppTheme.gray60)
        .padding(.horizontal, 14)
        .frame(height: 34)
        .background(isSelected ? AppTheme.brightTurquoise : AppTheme.blackTurquoise)
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
    }
    .buttonStyle(.plain)
  }
}
