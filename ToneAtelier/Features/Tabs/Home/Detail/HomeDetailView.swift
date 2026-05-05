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

  @Bindable var store: StoreOf<HomeDetailFeature>

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
          comments: store.comments,
          purchaseButtonTapped: { store.send(.purchaseButtonTapped, animation: .easeInOut(duration: 0.18)) }
        )
        .padding(.bottom, MainTabBarView.Layout.contentInsetHeight + 24)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(AppTheme.background.ignoresSafeArea())
    .navigationBarBackButtonHidden(true)
    .toolbar(.hidden, for: .navigationBar)
    .task {
      await store.send(.task).finish()
    }
    .fullScreenCover(
      // 표시 여부와 데이터를 분리: 시스템 dismiss(스와이프 등)는 set(false)로 정상 송출된다.
      isPresented: Binding(
        get: { store.activePayment != nil },
        set: { isPresented in
          if !isPresented {
            store.send(.paymentSheetDismissed)
          }
        }
      )
    ) {
      if let request = store.activePayment {
        IamportPaymentSheet(
          request: request,
          onComplete: { result in
            store.send(.paymentCompleted(result))
          }
        )
        .ignoresSafeArea()
      }
    }
    .alert($store.scope(state: \.alert, action: \.alert))
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
