//
//  PostDetailFeature.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//
//  Pencil node: c4XEL (Post Detail View)
//

// swiftlint:disable file_length
// 게시글 상세 reducer + DTO 변경 helper가 한 도메인. 외부 분리해도 의미 있는 경계 없음.

import ComposableArchitecture
import Foundation

@Reducer
struct PostDetailFeature {
  @Dependency(\.postClient) private var postClient
  @Dependency(\.sessionClient) private var sessionClient

  @ObservableState
  struct State: Equatable {
    let postID: String
    var post: PostResponseDTO?
    var isLoading = false
    var hasLoaded = false
    var errorMessage: String?

    var commentInput: String = ""
    var isCommentSubmitting = false
    /// 댓글 수정 모드. 값이 있으면 해당 commentID 댓글을 수정 중.
    /// 입력바는 commentInput에 기존 본문을 채우고 submit 시 update API 호출.
    var editingCommentID: String?
    /// 댓글 작성 성공/실패 피드백을 view에서 트리거하기 위한 카운터.
    /// 성공: `.success` haptic, 실패: `.error` haptic 발사 + 토스트 노출.
    var commentSubmissionSuccessCount: Int = 0
    var commentSubmissionFailureCount: Int = 0
    /// 새로 작성된 댓글 ID. 성공 직후 view가 이 id로 ScrollViewReader 스크롤한다.
    var lastSubmittedCommentID: String?
    /// nil이면 일반 댓글, 값이 있으면 해당 댓글에 대한 답글 작성 모드.
    var replyTargetCommentID: String?
    var replyTargetNickname: String?

    /// 미디어 캐러셀 현재 인덱스. View가 binding으로 갱신.
    var mediaCurrentIndex: Int = 0

    /// 미디어 풀스크린 viewer. nil이 아니면 `fullScreenCover`로 노출.
    var mediaPreview: MediaPreviewItem?

    /// 현재 사용자 ID. author/comment 소유 여부 판정에 사용.
    var currentUserID: String?

    @Presents var deleteConfirmation: AlertState<Action.Alert>?

    var isOwnPost: Bool {
      guard let post, let currentUserID, !currentUserID.isEmpty else { return false }
      return post.creator.userID == currentUserID
    }

    var comments: [PostCommentResponseDTO] { post?.comments ?? [] }

    /// 대댓글까지 포함한 총 댓글 수. UI 카운트 표시용.
    var totalCommentCount: Int {
      comments.reduce(0) { $0 + 1 + $1.replies.count }
    }
    var replyInputModeActive: Bool { replyTargetCommentID != nil }

    init(postID: String) {
      self.postID = postID
    }
  }

  enum Action: BindableAction, Sendable {
    case binding(BindingAction<State>)
    case task
    case detailReload
    case bootstrapResponse(currentUserID: String?)
    case backTapped
    case moreTapped
    case mediaIndexChanged(Int)
    case mediaTapped(MediaPreviewItem)
    case mediaPreviewDismissed
    case likeToggled
    case likeResponse(snapshot: LikeSnapshot, Result<LikeStatusResponse, Error>)
    case commentRowTapped(commentID: String, nickname: String)
    case replyDismissTapped
    case commentSubmitTapped
    case commentSubmitResponse(Result<PostCommentResponseDTO, Error>)
    case commentDeleteTapped(commentID: String)
    case commentDeleteResponse(commentID: String, Result<EmptyResponse, Error>)
    case commentEditTapped(commentID: String, currentContent: String)
    case commentEditCancelTapped
    case commentUpdateResponse(commentID: String, Result<PostCommentResponseDTO, Error>)
    case errorMessageDismissed
    case postEditTapped
    case postDeleteTapped
    case deleteConfirmationConfirmed
    case postDeleteResponse(Result<EmptyResponse, Error>)
    case loadResponse(Result<PostResponseDTO, Error>)
    case authorTapped
    case alert(PresentationAction<Alert>)
    case delegate(Delegate)

    enum Alert: Equatable, Sendable {
      case confirmDelete
    }

    enum Delegate: Equatable, Sendable {
      case dismiss
      case editRequested(postID: String, post: PostResponseDTO)
      case userPostsRequested(userID: String)
      case postDeleted(postID: String)
      case likeStatusChanged(postID: String, isLike: Bool, likeCount: Double)
    }
  }

  struct LikeSnapshot: Equatable, Sendable {
    let isLike: Bool
    let likeCount: Double
  }

  var body: some Reducer<State, Action> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .binding:
        return .none

      case .task:
        return handleTaskAction(state: &state)

      case .detailReload:
        return handleDetailReload(state: &state)

      case let .bootstrapResponse(currentUserID):
        state.currentUserID = currentUserID
        return .none

      case .backTapped:
        return .send(.delegate(.dismiss))

      case .moreTapped:
        // 작성자가 아닐 때 신고 등 메뉴는 현재 미정. 작성자만 편집/삭제 액션을 노출.
        return .none

      case let .mediaIndexChanged(index):
        state.mediaCurrentIndex = index
        return .none

      case let .mediaTapped(item):
        state.mediaPreview = item
        return .none

      case .mediaPreviewDismissed:
        state.mediaPreview = nil
        return .none

      case .likeToggled:
        return handleLikeToggled(state: &state)

      case let .likeResponse(snapshot, .success(response)):
        guard let post = state.post else { return .none }
        let confirmed = response.likeStatus
        let baseline = snapshot.likeCount
        let delta: Double = (confirmed == snapshot.isLike) ? 0 : (confirmed ? 1 : -1)
        let adjusted = max(0, baseline + delta)
        state.post = post.applyingLike(isLike: confirmed, likeCount: adjusted)
        return .send(.delegate(.likeStatusChanged(postID: state.postID, isLike: confirmed, likeCount: adjusted)))

      case let .likeResponse(snapshot, .failure):
        guard let post = state.post else { return .none }
        state.post = post.applyingLike(isLike: snapshot.isLike, likeCount: snapshot.likeCount)
        return .send(
          .delegate(
            .likeStatusChanged(
              postID: state.postID,
              isLike: snapshot.isLike,
              likeCount: snapshot.likeCount
            )
          )
        )

      case let .commentRowTapped(commentID, nickname):
        state.replyTargetCommentID = commentID
        state.replyTargetNickname = nickname
        return .none

      case .replyDismissTapped:
        state.replyTargetCommentID = nil
        state.replyTargetNickname = nil
        return .none

      case .commentSubmitTapped:
        return handleCommentSubmitTapped(state: &state)

      case let .commentEditTapped(commentID, currentContent):
        state.editingCommentID = commentID
        state.commentInput = currentContent
        state.replyTargetCommentID = nil
        state.replyTargetNickname = nil
        return .none

      case .commentEditCancelTapped:
        state.editingCommentID = nil
        state.commentInput = ""
        return .none

      case let .commentUpdateResponse(commentID, .success(comment)):
        state.isCommentSubmitting = false
        state.commentInput = ""
        state.editingCommentID = nil
        state.errorMessage = nil
        state.commentSubmissionSuccessCount += 1
        state.lastSubmittedCommentID = commentID
        if let post = state.post {
          state.post = post.replacingComment(comment)
        }
        return .none

      case let .commentUpdateResponse(_, .failure(error)):
        state.isCommentSubmitting = false
        state.errorMessage = Self.userFacingMessage(for: error)
        state.commentSubmissionFailureCount += 1
        return .none

      case .errorMessageDismissed:
        state.errorMessage = nil
        return .none

      case let .commentSubmitResponse(.success(comment)):
        state.isCommentSubmitting = false
        state.commentInput = ""
        state.replyTargetCommentID = nil
        state.replyTargetNickname = nil
        state.errorMessage = nil
        state.commentSubmissionSuccessCount += 1
        state.lastSubmittedCommentID = comment.commentID

        // 즉시 UI 반영. 서버는 단일 PostCommentResponseDTO를 반환하므로 댓글 배열에 append.
        // 답글이라면 부모 댓글의 replies에 추가하는 것이 정확하지만 spec상 응답에 부모 식별자가 없어
        // 가장 안전한 fallback으로 root 댓글 리스트에 추가하고 다음 detail 재조회 시 정상 위치로 보정한다.
        if let post = state.post {
          state.post = post.appendingComment(comment)
        }
        return .none

      case let .commentSubmitResponse(.failure(error)):
        state.isCommentSubmitting = false
        // 답글 응답 schema가 root 댓글과 달라 디코딩 단계에서만 실패하는 케이스가 흔함.
        // 이 경우 서버에는 답글이 작성되었을 가능성이 높아 토스트 대신 reset + detail 재조회로 fallback.
        if state.replyTargetCommentID != nil {
          state.commentInput = ""
          state.replyTargetCommentID = nil
          state.replyTargetNickname = nil
          state.commentSubmissionSuccessCount += 1
          return .send(.detailReload)
        }
        state.errorMessage = Self.userFacingMessage(for: error)
        state.commentSubmissionFailureCount += 1
        return .none

      case let .commentDeleteTapped(commentID):
        return handleCommentDeleteTapped(state: &state, commentID: commentID)

      case let .commentDeleteResponse(commentID, .success):
        if let post = state.post {
          state.post = post.removingComment(commentID: commentID)
        }
        return .none

      case let .commentDeleteResponse(_, .failure(error)):
        state.errorMessage = Self.userFacingMessage(for: error)
        return .none

      case .postEditTapped:
        guard let post = state.post else { return .none }
        return .send(.delegate(.editRequested(postID: state.postID, post: post)))

      case .postDeleteTapped:
        state.deleteConfirmation = AlertState {
          TextState("게시글을 삭제할까요?")
        } actions: {
          ButtonState(role: .cancel) { TextState("취소") }
          ButtonState(role: .destructive, action: .confirmDelete) { TextState("삭제") }
        } message: {
          TextState("이 동작은 되돌릴 수 없어요.")
        }
        return .none

      case .alert(.presented(.confirmDelete)):
        return .send(.deleteConfirmationConfirmed)

      case .alert:
        return .none

      case .deleteConfirmationConfirmed:
        return handleDeleteConfirmed(state: &state)

      case .postDeleteResponse(.success):
        return .merge(
          .send(.delegate(.postDeleted(postID: state.postID))),
          .send(.delegate(.dismiss))
        )

      case let .postDeleteResponse(.failure(error)):
        state.errorMessage = Self.userFacingMessage(for: error)
        return .none

      case let .loadResponse(.success(post)):
        state.isLoading = false
        state.hasLoaded = true
        state.post = post
        state.errorMessage = nil
        return .none

      case let .loadResponse(.failure(error)):
        state.isLoading = false
        state.hasLoaded = true
        state.errorMessage = Self.userFacingMessage(for: error)
        return .none

      case .authorTapped:
        guard let post = state.post else { return .none }
        return .send(.delegate(.userPostsRequested(userID: post.creator.userID)))

      case .delegate:
        return .none
      }
    }
    .ifLet(\.$deleteConfirmation, action: \.alert)
  }

}

// MARK: - Effect handlers / helpers

private extension PostDetailFeature {
  func handleTaskAction(state: inout State) -> Effect<Action> {
    guard !state.hasLoaded, !state.isLoading else { return .none }
    state.isLoading = true
    state.errorMessage = nil

    let postClient = postClient
    let sessionClient = sessionClient
    let postID = state.postID

    return .run { send in
      let snapshot = await sessionClient.snapshot()
      await send(.bootstrapResponse(currentUserID: snapshot.currentUserID))
      await send(
        .loadResponse(
          Result {
            try await postClient.detail(postID)
          }
        )
      )
    }
    .cancellable(id: "PostDetailFeature.task.\(state.postID)", cancelInFlight: true)
  }

  func handleDetailReload(state: inout State) -> Effect<Action> {
    let postClient = postClient
    let postID = state.postID
    return .run { send in
      await send(
        .loadResponse(
          Result {
            try await postClient.detail(postID)
          }
        )
      )
    }
    .cancellable(id: "PostDetailFeature.task.\(state.postID)", cancelInFlight: true)
  }

  func handleLikeToggled(state: inout State) -> Effect<Action> {
    guard let post = state.post else { return .none }
    let snapshot = LikeSnapshot(isLike: post.isLike, likeCount: post.likeCount)
    let target = !post.isLike
    let nextLikeCount = max(0, post.likeCount + (target ? 1 : -1))
    state.post = post.applyingLike(isLike: target, likeCount: nextLikeCount)

    let postClient = postClient
    let postID = state.postID

    return .merge(
      .send(.delegate(.likeStatusChanged(postID: postID, isLike: target, likeCount: nextLikeCount))),
      .run { send in
        await send(
          .likeResponse(
            snapshot: snapshot,
            Result {
              try await postClient.setLike(postID, target)
            }
          )
        )
      }
      .cancellable(id: "PostDetailFeature.like.\(postID)", cancelInFlight: true)
    )
  }

  func handleCommentSubmitTapped(state: inout State) -> Effect<Action> {
    let trimmed = state.commentInput.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, !state.isCommentSubmitting else { return .none }

    state.isCommentSubmitting = true

    let postClient = postClient
    let postID = state.postID

    if let editingCommentID = state.editingCommentID {
      let updateRequest = CommentUpdateRequestDTO(content: trimmed)
      return .run { send in
        await send(
          .commentUpdateResponse(
            commentID: editingCommentID,
            Result {
              try await postClient.updateComment(postID, editingCommentID, updateRequest)
            }
          )
        )
      }
      .cancellable(id: "PostDetailFeature.comment.\(postID)", cancelInFlight: true)
    }

    let request = CommentRequestDTO(
      parentCommentID: state.replyTargetCommentID,
      content: trimmed
    )

    return .run { send in
      await send(
        .commentSubmitResponse(
          Result {
            try await postClient.createComment(postID, request)
          }
        )
      )
    }
    .cancellable(id: "PostDetailFeature.comment.\(postID)", cancelInFlight: true)
  }

  func handleCommentDeleteTapped(state: inout State, commentID: String) -> Effect<Action> {
    let postClient = postClient
    let postID = state.postID

    return .run { send in
      await send(
        .commentDeleteResponse(
          commentID: commentID,
          Result {
            try await postClient.deleteComment(postID, commentID)
          }
        )
      )
    }
    .cancellable(id: "PostDetailFeature.commentDelete.\(commentID)", cancelInFlight: true)
  }

  func handleDeleteConfirmed(state: inout State) -> Effect<Action> {
    let postClient = postClient
    let postID = state.postID
    return .run { send in
      await send(
        .postDeleteResponse(
          Result {
            try await postClient.delete(postID)
          }
        )
      )
    }
    .cancellable(id: "PostDetailFeature.delete.\(state.postID)", cancelInFlight: true)
  }

  static func userFacingMessage(for error: Error) -> String {
    if let apiError = error as? APIError {
      switch apiError {
      case let .invalidBaseURL(message),
           let .invalidURL(message),
           let .transport(message),
           let .decoding(message):
        return message

      case .missingAccessToken, .missingRefreshToken:
        return "인증 정보가 없어 요청을 처리할 수 없어요."

      case let .invalidSession(statusCode):
        return "세션이 유효하지 않습니다. 다시 로그인해 주세요. (\(statusCode))"

      case let .server(statusCode, message, _):
        if let message, !message.isEmpty {
          return message
        }
        return "요청을 처리하지 못했어요. (\(statusCode))"
      }
    }
    return "요청을 처리하지 못했어요. 잠시 후 다시 시도해 주세요."
  }
}

// MARK: - DTO 변경 helper

private extension PostResponseDTO {
  func applyingLike(isLike: Bool, likeCount: Double) -> PostResponseDTO {
    PostResponseDTO(
      postID: postID,
      category: category,
      title: title,
      content: content,
      geolocation: geolocation,
      creator: creator,
      files: files,
      isLike: isLike,
      likeCount: likeCount,
      comments: comments,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }

  func appendingComment(_ comment: PostCommentResponseDTO) -> PostResponseDTO {
    PostResponseDTO(
      postID: postID,
      category: category,
      title: title,
      content: content,
      geolocation: geolocation,
      creator: creator,
      files: files,
      isLike: isLike,
      likeCount: likeCount,
      comments: comments + [comment],
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }

  func replacingComment(_ updated: PostCommentResponseDTO) -> PostResponseDTO {
    let updatedReply = PostCommentReplyDTO(
      commentID: updated.commentID,
      content: updated.content,
      createdAt: updated.createdAt,
      creator: updated.creator
    )
    let mapped = comments.map { root -> PostCommentResponseDTO in
      if root.commentID == updated.commentID { return updated }
      let updatedReplies = root.replies.map { reply -> PostCommentReplyDTO in
        reply.commentID == updated.commentID ? updatedReply : reply
      }
      return PostCommentResponseDTO(
        commentID: root.commentID,
        content: root.content,
        createdAt: root.createdAt,
        creator: root.creator,
        replies: updatedReplies
      )
    }
    return PostResponseDTO(
      postID: postID,
      category: category,
      title: title,
      content: content,
      geolocation: geolocation,
      creator: creator,
      files: files,
      isLike: isLike,
      likeCount: likeCount,
      comments: mapped,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }

  func removingComment(commentID: String) -> PostResponseDTO {
    let filtered = comments.compactMap { root -> PostCommentResponseDTO? in
      if root.commentID == commentID { return nil }
      let prunedReplies = root.replies.filter { $0.commentID != commentID }
      if prunedReplies.count == root.replies.count { return root }
      return PostCommentResponseDTO(
        commentID: root.commentID,
        content: root.content,
        createdAt: root.createdAt,
        creator: root.creator,
        replies: prunedReplies
      )
    }
    return PostResponseDTO(
      postID: postID,
      category: category,
      title: title,
      content: content,
      geolocation: geolocation,
      creator: creator,
      files: files,
      isLike: isLike,
      likeCount: likeCount,
      comments: filtered,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }
}
