//
//  PostDetailView.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//
//  Pencil node: c4XEL (Post Detail View)
//

import ComposableArchitecture
import SwiftUI

struct PostDetailView: View {
  @Bindable var store: StoreOf<PostDetailFeature>
  @FocusState private var commentFieldFocused: Bool

  var body: some View {
    content
      .background(AppTheme.background.ignoresSafeArea())
      .safeAreaInset(edge: .bottom, spacing: 0) {
        bottomInputBar
          .padding(.horizontal, 20)
          .padding(.top, 8)
          .padding(.bottom, MainTabBarView.Layout.contentInsetHeight + 8)
          .background(
            AppTheme.background
              .ignoresSafeArea(edges: .bottom)
          )
      }
      .overlay(alignment: .top) {
        if let message = store.errorMessage {
          errorToast(message: message)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
      }
      .animation(.easeInOut(duration: 0.18), value: store.errorMessage)
      .toolbar(.hidden, for: .navigationBar)
      .alert($store.scope(state: \.deleteConfirmation, action: \.alert))
      .fullScreenCover(item: mediaPreviewBinding) { item in
        mediaPreview(for: item)
      }
      .sensoryFeedback(.success, trigger: store.commentSubmissionSuccessCount)
      .sensoryFeedback(.error, trigger: store.commentSubmissionFailureCount)
      .onChange(of: store.commentSubmissionSuccessCount) { _, _ in
        commentFieldFocused = false
      }
      .task {
        await store.send(.task).finish()
      }
  }

  /// `fullScreenCover(item:)`용 binding. 자식의 swipe-down 등 nil set이 들어오면
  /// reducer에 dismiss 액션을 일관되게 송출한다.
  private var mediaPreviewBinding: Binding<MediaPreviewItem?> {
    Binding(
      get: { store.mediaPreview },
      set: { newValue in
        if newValue == nil {
          store.send(.mediaPreviewDismissed)
        }
      }
    )
  }

  @ViewBuilder
  private func mediaPreview(for item: MediaPreviewItem) -> some View {
    switch item {
    case let .photo(paths, initialIndex):
      PhotoZoomView(paths: paths, initialIndex: initialIndex) {
        store.send(.mediaPreviewDismissed)
      }
    case let .video(path):
      VideoPlayerScreenView(path: path) {
        store.send(.mediaPreviewDismissed)
      }
    }
  }

  // MARK: - Content

  @ViewBuilder
  private var content: some View {
    if store.isLoading && store.post == nil {
      loadingView
    } else if let message = store.errorMessage, store.post == nil {
      errorView(message: message)
    } else {
      detailScroll
    }
  }

  private var detailScroll: some View {
    VStack(spacing: 0) {
      headerBar

      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          PostMediaCarouselView(
            files: store.post?.files ?? [],
            currentIndex: $store.mediaCurrentIndex,
            onMediaTap: { store.send(.mediaTapped($0)) }
          )
          .padding(.horizontal, 20)
          .accessibilityIdentifier("post_detail_media_carousel")

          if let post = store.post {
            PostAuthorRowView(
              creator: post.creator,
              createdAtRelative: post.createdAt.relativeKoreanShort,
              isOwn: store.isOwnPost,
              authorAction: { store.send(.authorTapped) },
              editAction: { store.send(.postEditTapped) },
              deleteAction: { store.send(.postDeleteTapped) }
            )
            .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 8) {
              Text(post.title)
                .pretendard(.title1)
                .foregroundStyle(AppTheme.gray30)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("post_detail_title")

              Text(post.content)
                .pretendard(.caption1)
                .foregroundStyle(AppTheme.gray60)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("post_detail_body")
            }
            .padding(.horizontal, 20)

            PostLocationCardView(geolocation: post.geolocation)
              .padding(.horizontal, 20)

            PostActionsBarView(
              isLike: post.isLike,
              likeCount: post.likeCount,
              commentCount: store.comments.count,
              likeAction: { store.send(.likeToggled) }
            )
            .padding(.horizontal, 20)

            commentsSection(for: post)
          }
        }
        .padding(.top, 8)
        .padding(.bottom, 24)
      }
      .scrollIndicators(.hidden)
    }
  }

  private var headerBar: some View {
    HStack(spacing: 0) {
      Button {
        store.send(.backTapped)
      } label: {
        Image(systemName: "chevron.left")
          .font(AppTheme.symbol(size: 18, weight: .regular))
          .foregroundStyle(AppTheme.gray60)
          .frame(width: 44, height: 44)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("뒤로")
      .accessibilityIdentifier("post_detail_back_button")

      Spacer(minLength: 0)

      Text("DETAIL")
        .mulgyeol(.pageTitle)
        .foregroundStyle(AppTheme.gray60)
        .accessibilityIdentifier("post_detail_header_title")

      Spacer(minLength: 0)

      Button {
        store.send(.moreTapped)
      } label: {
        Image(systemName: "ellipsis")
          .font(AppTheme.symbol(size: 18, weight: .regular))
          .foregroundStyle(AppTheme.gray60)
          .frame(width: 44, height: 44)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("더보기")
    }
    .frame(height: 56)
    .padding(.horizontal, 8)
  }

  private func commentsSection(for post: PostResponseDTO) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("댓글")
          .pretendard(.body3Bold)
          .foregroundStyle(AppTheme.gray30)
        Text("\(store.totalCommentCount)")
          .pretendard(.captionBold)
          .foregroundStyle(AppTheme.gray60)
        Spacer(minLength: 0)
      }

      if store.comments.isEmpty {
        Text("첫 댓글을 남겨보세요.")
          .pretendard(.caption1)
          .foregroundStyle(AppTheme.gray75)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 16)
      } else {
        VStack(alignment: .leading, spacing: 14) {
          ForEach(store.comments, id: \.commentID) { comment in
            CommentRowView(
              comment: comment.asCommentDisplay,
              isOwn: store.currentUserID == comment.creator.userID,
              isReplyTarget: store.replyTargetCommentID == comment.commentID,
              isEditing: store.editingCommentID == comment.commentID,
              editingCommentID: store.editingCommentID,
              replyOwnerEvaluator: { store.currentUserID == $0.creatorUserID },
              onReplyTapped: {
                store.send(.commentRowTapped(commentID: comment.commentID, nickname: comment.creator.nick))
              },
              onEditTapped: {
                store.send(.commentEditTapped(commentID: comment.commentID, currentContent: comment.content))
                commentFieldFocused = true
              },
              onDeleteTapped: {
                store.send(.commentDeleteTapped(commentID: comment.commentID))
              },
              onReplyEditTapped: { reply in
                store.send(.commentEditTapped(commentID: reply.commentID, currentContent: reply.content))
                commentFieldFocused = true
              },
              onReplyDeleteTapped: { reply in
                store.send(.commentDeleteTapped(commentID: reply.commentID))
              }
            )
          }
        }
      }
    }
    .padding(12)
    .background(AppTheme.blackTurquoise)
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    .padding(.horizontal, 20)
  }

  private var bottomInputBar: some View {
    PostCommentInputBarView(
      text: $store.commentInput,
      isSubmitting: store.isCommentSubmitting,
      replyTargetNickname: store.replyTargetNickname,
      isFocused: $commentFieldFocused,
      onSubmit: { store.send(.commentSubmitTapped) },
      onReplyDismiss: { store.send(.replyDismissTapped) }
    )
  }

}

// MARK: - States / Toast

private extension PostDetailView {
  func errorToast(message: String) -> some View {
    Text(message)
      .pretendard(.caption1)
      .foregroundStyle(AppTheme.gray30)
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
      .background(AppTheme.deepTurquoise)
      .clipShape(Capsule())
      .padding(.top, 12)
      .onAppear {
        Task { @MainActor in
          try? await Task.sleep(for: .seconds(2.5))
          store.send(.errorMessageDismissed)
        }
      }
  }

  var loadingView: some View {
    VStack(spacing: 12) {
      ProgressView()
        .tint(AppTheme.gray45)
      Text("게시글을 불러오는 중입니다.")
        .pretendard(.body3)
        .foregroundStyle(AppTheme.gray60)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  func errorView(message: String) -> some View {
    VStack(spacing: 12) {
      Image(systemName: "exclamationmark.triangle")
        .font(AppTheme.symbol(size: 28, weight: .regular))
        .foregroundStyle(AppTheme.gray60)
      Text(message)
        .pretendard(.body3)
        .foregroundStyle(AppTheme.gray60)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
      Button("뒤로") {
        store.send(.backTapped)
      }
      .pretendard(.body3Bold)
      .foregroundStyle(AppTheme.gray45)
      .frame(height: 40)
      .padding(.horizontal, 20)
      .background(AppTheme.deepTurquoise)
      .clipShape(Capsule())
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

private extension String {
  var relativeKoreanShort: String {
    let formatters = PostDetailHeaderFormatters.self
    let date = formatters.iso.date(from: self) ?? formatters.isoNoFraction.date(from: self)
    guard let date else { return "" }
    let interval = Date().timeIntervalSince(date)
    return formatters.relative.localizedString(fromTimeInterval: -max(interval, 0))
  }
}

private enum PostDetailHeaderFormatters {
  nonisolated(unsafe) static let iso: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  nonisolated(unsafe) static let isoNoFraction: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()

  nonisolated(unsafe) static let relative: RelativeDateTimeFormatter = {
    let formatter = RelativeDateTimeFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.unitsStyle = .short
    return formatter
  }()
}

#Preview {
  NavigationStack {
    PostDetailView(
      store: Store(initialState: PostDetailFeature.State(postID: "preview")) {
        PostDetailFeature()
      }
    )
  }
  .preferredColorScheme(.dark)
}
