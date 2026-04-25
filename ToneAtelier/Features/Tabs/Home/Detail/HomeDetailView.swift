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

      Text(store.trend.title)
        .font(HomeTheme.pretendard(size: 16, weight: .semibold))
        .foregroundStyle(HomeTheme.gray45)

      Text("좋아요 \(store.trend.likeCount)")
        .font(HomeTheme.pretendard(size: 14, weight: .medium))
        .foregroundStyle(HomeTheme.gray75)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(HomeTheme.background.ignoresSafeArea())
    .navigationTitle(store.title)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar(.visible, for: .navigationBar)
  }
}

#Preview {
  NavigationStack {
    HomeDetailView(
      store: Store(
        initialState: HomeDetailFeature.State(
          trend: HomeTrend(
            id: "preview-trend",
            title: "트렌드 1",
            likeCount: 99,
            imageURL: nil
          )
        )
      ) {
        HomeDetailFeature()
      }
    )
  }
}
