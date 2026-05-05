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
  @FocusState private var commentFieldFocused: Bool

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
          currentUserID: store.currentUserID,
          replyTargetCommentID: store.replyTargetCommentID,
          editingCommentID: store.editingCommentID,
          onReplyTrigger: { commentID, nickname in
            store.send(.commentRowTapped(commentID: commentID, nickname: nickname))
            commentFieldFocused = true
          },
          onEditTrigger: { commentID, content in
            store.send(.commentEditTapped(commentID: commentID, currentContent: content))
            commentFieldFocused = true
          },
          onDeleteTrigger: { commentID in
            store.send(.commentDeleteTapped(commentID: commentID))
          },
          purchaseButtonTapped: { store.send(.purchaseButtonTapped, animation: .easeInOut(duration: 0.18)) }
        )
        .padding(.bottom, 24)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(AppTheme.background.ignoresSafeArea())
    .safeAreaInset(edge: .bottom, spacing: 0) {
      CommentInputBarView(
        text: commentInputBinding,
        isSubmitting: store.isCommentSubmitting,
        replyTargetNickname: store.replyTargetNickname,
        isFocused: $commentFieldFocused,
        onSubmit: { store.send(.commentSubmitTapped) },
        onReplyDismiss: { store.send(.replyDismissTapped) }
      )
      .padding(.horizontal, 20)
      .padding(.top, 8)
      .padding(.bottom, MainTabBarView.Layout.contentInsetHeight + 8)
      .background(
        AppTheme.background
          .ignoresSafeArea(edges: .bottom)
      )
    }
    .navigationBarBackButtonHidden(true)
    .toolbar(.hidden, for: .navigationBar)
    .task {
      await store.send(.task).finish()
    }
    .fullScreenCover(
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

  private var commentInputBinding: Binding<String> {
    Binding(
      get: { store.commentInput },
      set: { store.send(.commentInputChanged($0)) }
    )
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
