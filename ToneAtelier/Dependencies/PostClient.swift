//
//  PostClient.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import ComposableArchitecture
import Foundation

// MARK: - Query

struct GeolocationPostsQuery: Equatable, Sendable {
  var category: String?
  var longitude: Double?
  var latitude: Double?
  var maxDistance: Int?
  var limit: Int?
  var next: String?
  var orderBy: String?

  var queryItems: [URLQueryItem] {
    [
      .optional(name: "category", value: category),
      .optional(name: "longitude", value: longitude),
      .optional(name: "latitude", value: latitude),
      .optional(name: "maxDistance", value: maxDistance),
      .optional(name: "limit", value: limit),
      .optional(name: "next", value: next),
      .optional(name: "order_by", value: orderBy)
    ]
      .compactMap { $0 }
  }
}

struct UserPostListQuery: Equatable, Sendable {
  var category: String?
  var limit: Int?
  var next: String?

  var queryItems: [URLQueryItem] {
    [
      .optional(name: "category", value: category),
      .optional(name: "limit", value: limit),
      .optional(name: "next", value: next)
    ]
      .compactMap { $0 }
  }
}

struct PostClient {
  var uploadFiles: @Sendable (_ files: [UploadFile]) async throws -> UploadedFilesResponse
  var create: @Sendable (_ request: PostRequestDTO) async throws -> PostResponseDTO
  var listGeolocation: @Sendable (_ query: GeolocationPostsQuery) async throws -> PostSummaryPaginationResponseDTO
  var search: @Sendable (_ title: String?) async throws -> PostSummaryListResponseDTO
  var detail: @Sendable (_ postID: String) async throws -> PostResponseDTO
  var update: @Sendable (_ postID: String, _ request: PostUpdateRequestDTO) async throws -> PostResponseDTO
  var delete: @Sendable (_ postID: String) async throws -> EmptyResponse
  var setLike: @Sendable (_ postID: String, _ likeStatus: Bool) async throws -> LikeStatusResponse
  var userPosts: @Sendable (_ userID: String, _ query: UserPostListQuery) async throws -> PostSummaryPaginationResponseDTO
  var likedPosts: @Sendable (_ query: UserPostListQuery) async throws -> PostSummaryPaginationResponseDTO
  var createComment: @Sendable (_ postID: String, _ request: CommentRequestDTO) async throws -> PostCommentResponseDTO
  var updateComment: @Sendable (_ postID: String, _ commentID: String, _ request: CommentUpdateRequestDTO) async throws -> PostCommentResponseDTO
  var deleteComment: @Sendable (_ postID: String, _ commentID: String) async throws -> EmptyResponse
}

extension PostClient: DependencyKey {
  static var liveValue: PostClient {
    @Dependency(\.httpClient) var httpClient

    return PostClient(
      uploadFiles: { files in
        try await httpClient.send(
          APIEndpoint<UploadedFilesResponse>(router: PostRouter.uploadFiles(files))
        )
      },
      create: { request in
        try await httpClient.send(
          APIEndpoint<PostResponseDTO>(router: PostRouter.create(request))
        )
      },
      listGeolocation: { query in
        try await httpClient.send(
          APIEndpoint<PostSummaryPaginationResponseDTO>(router: PostRouter.listGeolocation(query))
        )
      },
      search: { title in
        try await httpClient.send(
          APIEndpoint<PostSummaryListResponseDTO>(router: PostRouter.search(title: title))
        )
      },
      detail: { postID in
        try await httpClient.send(
          APIEndpoint<PostResponseDTO>(router: PostRouter.detail(postID: postID))
        )
      },
      update: { postID, request in
        try await httpClient.send(
          APIEndpoint<PostResponseDTO>(router: PostRouter.update(postID: postID, request))
        )
      },
      delete: { postID in
        try await httpClient.send(
          APIEndpoint<EmptyResponse>(router: PostRouter.delete(postID: postID))
        )
      },
      setLike: { postID, likeStatus in
        try await httpClient.send(
          APIEndpoint<LikeStatusResponse>(router: PostRouter.setLike(postID: postID, status: likeStatus))
        )
      },
      userPosts: { userID, query in
        try await httpClient.send(
          APIEndpoint<PostSummaryPaginationResponseDTO>(router: PostRouter.userPosts(userID: userID, query))
        )
      },
      likedPosts: { query in
        try await httpClient.send(
          APIEndpoint<PostSummaryPaginationResponseDTO>(router: PostRouter.likedPosts(query))
        )
      },
      createComment: { postID, request in
        try await httpClient.send(
          APIEndpoint<PostCommentResponseDTO>(router: PostRouter.createComment(postID: postID, request))
        )
      },
      updateComment: { postID, commentID, request in
        try await httpClient.send(
          APIEndpoint<PostCommentResponseDTO>(router: PostRouter.updateComment(postID: postID, commentID: commentID, request))
        )
      },
      deleteComment: { postID, commentID in
        try await httpClient.send(
          APIEndpoint<EmptyResponse>(router: PostRouter.deleteComment(postID: postID, commentID: commentID))
        )
      }
    )
  }

  static let testValue = PostClient(
    uploadFiles: { _ in throw APIError.transport("PostClient.uploadFiles testValue") },
    create: { _ in throw APIError.transport("PostClient.create testValue") },
    listGeolocation: { _ in throw APIError.transport("PostClient.listGeolocation testValue") },
    search: { _ in throw APIError.transport("PostClient.search testValue") },
    detail: { _ in throw APIError.transport("PostClient.detail testValue") },
    update: { _, _ in throw APIError.transport("PostClient.update testValue") },
    delete: { _ in throw APIError.transport("PostClient.delete testValue") },
    setLike: { _, _ in throw APIError.transport("PostClient.setLike testValue") },
    userPosts: { _, _ in throw APIError.transport("PostClient.userPosts testValue") },
    likedPosts: { _ in throw APIError.transport("PostClient.likedPosts testValue") },
    createComment: { _, _ in throw APIError.transport("PostClient.createComment testValue") },
    updateComment: { _, _, _ in throw APIError.transport("PostClient.updateComment testValue") },
    deleteComment: { _, _ in throw APIError.transport("PostClient.deleteComment testValue") }
  )
}

extension DependencyValues {
  var postClient: PostClient {
    get { self[PostClient.self] }
    set { self[PostClient.self] = newValue }
  }
}
