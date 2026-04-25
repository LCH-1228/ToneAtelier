//
//  FeedView.swift
//  ToneAtelier
//
//  Created by Codex on 4/25/26.
//

import ComposableArchitecture
import SwiftUI

struct FeedView: View {
  let store: StoreOf<FeedFeature>

  var body: some View {
    VStack(spacing: 18) {
      Image(systemName: "square.stack.3d.up.fill")
        .font(.system(size: 42, weight: .semibold))
        .foregroundStyle(HomeTheme.gray45)

      Text("Feed View")
        .font(HomeTheme.pretendard(size: 24, weight: .bold))
        .foregroundStyle(HomeTheme.gray60)

      Text("\(store.category.title) 카테고리 더미 화면입니다.")
        .font(HomeTheme.pretendard(size: 15, weight: .medium))
        .foregroundStyle(HomeTheme.gray75)
        .multilineTextAlignment(.center)
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
    FeedView(
      store: Store(
        initialState: FeedFeature.State(category: .food)
      ) {
        FeedFeature()
      }
    )
  }
}
