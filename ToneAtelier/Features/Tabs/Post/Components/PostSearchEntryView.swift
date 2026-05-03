//
//  PostSearchEntryView.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//
//  Pencil node: BwNEX (Post 검색 진입 셀)
//

import SwiftUI

struct PostSearchEntryView: View {
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        Image(systemName: "magnifyingglass")
          .font(AppTheme.symbol(size: 14, weight: .medium))
          .foregroundStyle(AppTheme.gray60)

        Text("제목으로 게시글 검색")
          .font(AppTheme.pretendard(size: 14, weight: .regular))
          .foregroundStyle(AppTheme.gray60)

        Spacer(minLength: 0)
      }
      .padding(.horizontal, 16)
      .frame(height: 44)
      .background(AppTheme.blackTurquoise)
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("게시글 검색")
  }
}

#Preview {
  PostSearchEntryView(action: {})
    .padding(20)
    .background(AppTheme.background)
    .preferredColorScheme(.dark)
}
