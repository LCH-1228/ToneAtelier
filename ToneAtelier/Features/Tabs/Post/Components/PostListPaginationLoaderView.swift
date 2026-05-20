//
//  PostListPaginationLoaderView.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//
//  Pencil node: Q6WusJ (페이지네이션 로더, "다음 게시글 불러오는 중")
//

import SwiftUI

struct PostListPaginationLoaderView: View {
  let isLoading: Bool

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "arrow.triangle.2.circlepath")
        .font(AppTheme.symbol(size: 14, weight: .medium))
        .foregroundStyle(AppTheme.gray60)
        .rotationEffect(.degrees(isLoading ? 360 : 0))
        .animation(
          isLoading
            ? .linear(duration: 1).repeatForever(autoreverses: false)
            : .default,
          value: isLoading
        )

      Text("다음 게시글 불러오는 중")
        .pretendard(.body3)
        .foregroundStyle(AppTheme.gray60)
    }
    .frame(maxWidth: .infinity)
    .frame(height: 48)
    .background(AppTheme.blackTurquoise)
    .clipShape(Capsule())
  }
}

#Preview {
  PostListPaginationLoaderView(isLoading: true)
    .padding(20)
    .background(AppTheme.background)
    .preferredColorScheme(.dark)
}
