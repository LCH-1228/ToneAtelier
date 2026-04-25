//
//  HomeDetailView.swift
//  ToneAtelier
//
//  Created by Codex on 4/25/26.
//

import ComposableArchitecture
import SwiftUI

struct HomeDetailView: View {
  let store: StoreOf<HomeDetailFeature>

  var body: some View {
    VStack(spacing: 18) {
      Image(systemName: "sparkles.rectangle.stack.fill")
        .font(.system(size: 42, weight: .semibold))
        .foregroundStyle(HomeTheme.gray45)

      Text("Detail View")
        .font(HomeTheme.pretendard(size: 24, weight: .bold))
        .foregroundStyle(HomeTheme.gray60)

      Text(store.title)
        .font(HomeTheme.pretendard(size: 16, weight: .semibold))
        .foregroundStyle(HomeTheme.gray45)

      if let summary = store.summary {
        Text(summary)
          .font(HomeTheme.pretendard(size: 14, weight: .medium))
          .foregroundStyle(HomeTheme.gray75)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 32)
      }

      if let likeCount = store.likeCount {
        Text("좋아요 \(likeCount)")
          .font(HomeTheme.pretendard(size: 14, weight: .medium))
          .foregroundStyle(HomeTheme.gray75)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(HomeTheme.background.ignoresSafeArea())
    .navigationTitle(store.navigationTitle)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar(.visible, for: .navigationBar)
  }
}

#Preview {
  NavigationStack {
    HomeDetailView(
      store: Store(
        initialState: HomeDetailFeature.State(
          featuredFilter: HomeFeaturedFilter(
            id: "preview-filter",
            title: "오늘의 필터",
            summary: "필터 설명이 표시되는 영역입니다.",
            imageURL: nil
          )
        )
      ) {
        HomeDetailFeature()
      }
    )
  }
}
