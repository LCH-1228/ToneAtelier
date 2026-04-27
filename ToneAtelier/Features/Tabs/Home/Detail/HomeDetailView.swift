//
//  HomeDetailView.swift
//  ToneAtelier
//
//  Created by Codex on 4/25/26.
//

import ComposableArchitecture
import SwiftUI

struct HomeDetailView: View {
  @Environment(\.dismiss) private var dismiss

  let store: StoreOf<HomeDetailFeature>

  var body: some View {
    VStack(spacing: 0) {
      HomeDetailNavigationHeader(
        title: store.title,
        backAction: { dismiss() },
        isLiked: store.isLiked,
        isLikeRequestInFlight: store.isLikeRequestInFlight,
        likeAction: { store.send(.likeButtonTapped) }
      )

      ScrollView(.vertical, showsIndicators: false) {
        HomeDetailContent(
          summary: store.summary,
          likeCount: store.likeCount,
          price: store.price,
          buyerCount: store.buyerCount,
          isPurchased: store.isPurchased,
          afterImageURL: store.afterImageURL,
          beforeImageURL: store.beforeImageURL,
          comparisonSplitRatio: store.comparisonSplitRatio,
          comparisonSplitRatioChanged: { store.send(.comparisonSplitRatioChanged($0)) },
          authorName: store.authorName,
          authorSubtitle: store.authorSubtitle,
          authorProfileImageURL: store.authorProfileImageURL,
          authorTags: store.authorTags,
          exif: store.exif,
          presets: store.presets,
          purchaseButtonTapped: { store.send(.purchaseButtonTapped, animation: .easeInOut(duration: 0.18)) }
        )
        .padding(.bottom, 44)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(HomeTheme.background.ignoresSafeArea())
    .navigationBarBackButtonHidden(true)
    .toolbar(.hidden, for: .navigationBar)
    .task {
      await store.send(.task).finish()
    }
  }
}

#Preview("Locked") {
  NavigationStack {
    HomeDetailView(
      store: Store(
        initialState: HomeDetailFeature.State(
          id: "preview-filter",
          title: "청록새록",
          summary: "햇살 아래 돋아나는 새싹처럼,\n맑고 투명한 빛을 담은 자연 감성 필터입니다.",
          likeCount: 800
        )
      ) {
        HomeDetailFeature()
      }
    )
  }
}

#Preview("Purchased") {
  NavigationStack {
    HomeDetailView(
      store: Store(
        initialState: HomeDetailFeature.State(
          id: "preview-filter",
          title: "청록새록",
          summary: "햇살 아래 돋아나는 새싹처럼,\n맑고 투명한 빛을 담은 자연 감성 필터입니다.",
          likeCount: 800,
          isPurchased: true
        )
      ) {
        HomeDetailFeature()
      }
    )
  }
}
