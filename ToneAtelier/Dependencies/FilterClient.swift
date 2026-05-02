//
//  FilterClient.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import ComposableArchitecture
import Foundation

// MARK: - Query

struct FilterListQuery: Equatable, Sendable {
  var next: String?
  var limit: Int?
  var category: String?
  var orderBy: String?

  var queryItems: [URLQueryItem] {
    [
      next.map { URLQueryItem(name: "next", value: $0) },
      .optional(name: "limit", value: limit),
      .optional(name: "category", value: category),
      .optional(name: "order_by", value: orderBy),
    ]
      .compactMap { $0 }
  }
}

struct UserFilterListQuery: Equatable, Sendable {
  var next: String?
  var limit: Int?
  var category: String?

  var queryItems: [URLQueryItem] {
    [
      .optional(name: "next", value: next),
      .optional(name: "limit", value: limit),
      .optional(name: "category", value: category),
    ]
      .compactMap { $0 }
  }
}

struct FilterClient {
  var uploadFiles: @Sendable (_ files: [UploadFile]) async throws -> UploadedFilesResponse
  var create: @Sendable (_ request: FilterRequestDTO) async throws -> FilterResponseDTO
  var list: @Sendable (_ query: FilterListQuery) async throws -> FilterSummaryPaginationListResponseDTO
  var detail: @Sendable (_ filterID: String) async throws -> FilterResponseDTO
  var update: @Sendable (_ filterID: String, _ request: FilterUpdateRequestDTO) async throws -> FilterResponseDTO
  var delete: @Sendable (_ filterID: String) async throws -> EmptyResponse
  var setLike: @Sendable (_ filterID: String, _ likeStatus: Bool) async throws -> LikeStatusResponse
  var userFilters: @Sendable (_ userID: String, _ query: UserFilterListQuery) async throws -> FilterSummaryPaginationListResponseDTO
  var likedFilters: @Sendable (_ query: UserFilterListQuery) async throws -> FilterSummaryPaginationListResponseDTO
  var hotTrend: @Sendable () async throws -> FilterSummaryListResponseDTO
  var todayFilter: @Sendable () async throws -> TodayFilterResponseDTO
  var createComment: @Sendable (_ filterID: String, _ request: CommentRequestDTO) async throws -> FilterCommentResponseDTO
  var updateComment: @Sendable (_ filterID: String, _ commentID: String, _ request: CommentUpdateRequestDTO) async throws -> FilterCommentResponseDTO
  var deleteComment: @Sendable (_ filterID: String, _ commentID: String) async throws -> EmptyResponse
}

extension FilterClient: DependencyKey {
  static var liveValue: FilterClient {
    @Dependency(\.httpClient) var httpClient

    return FilterClient(
      uploadFiles: { files in
        try await httpClient.send(
          APIEndpoint<UploadedFilesResponse>(router: FilterRouter.uploadFiles(files))
        )
      },
      create: { request in
        try await httpClient.send(
          APIEndpoint<FilterResponseDTO>(router: FilterRouter.create(request))
        )
      },
      list: { query in
        try await httpClient.send(
          APIEndpoint<FilterSummaryPaginationListResponseDTO>(router: FilterRouter.list(query))
        )
      },
      detail: { filterID in
        try await httpClient.send(
          APIEndpoint<FilterResponseDTO>(router: FilterRouter.detail(filterID: filterID))
        )
      },
      update: { filterID, request in
        try await httpClient.send(
          APIEndpoint<FilterResponseDTO>(router: FilterRouter.update(filterID: filterID, request))
        )
      },
      delete: { filterID in
        try await httpClient.send(
          APIEndpoint<EmptyResponse>(router: FilterRouter.delete(filterID: filterID))
        )
      },
      setLike: { filterID, likeStatus in
        try await httpClient.send(
          APIEndpoint<LikeStatusResponse>(router: FilterRouter.setLike(filterID: filterID, status: likeStatus))
        )
      },
      userFilters: { userID, query in
        try await httpClient.send(
          APIEndpoint<FilterSummaryPaginationListResponseDTO>(router: FilterRouter.userFilters(userID: userID, query))
        )
      },
      likedFilters: { query in
        try await httpClient.send(
          APIEndpoint<FilterSummaryPaginationListResponseDTO>(router: FilterRouter.likedFilters(query))
        )
      },
      hotTrend: {
        try await httpClient.send(
          APIEndpoint<FilterSummaryListResponseDTO>(router: FilterRouter.hotTrend)
        )
      },
      todayFilter: {
        try await httpClient.send(
          APIEndpoint<TodayFilterResponseDTO>(router: FilterRouter.todayFilter)
        )
      },
      createComment: { filterID, request in
        try await httpClient.send(
          APIEndpoint<FilterCommentResponseDTO>(router: FilterRouter.createComment(filterID: filterID, request))
        )
      },
      updateComment: { filterID, commentID, request in
        try await httpClient.send(
          APIEndpoint<FilterCommentResponseDTO>(router: FilterRouter.updateComment(filterID: filterID, commentID: commentID, request))
        )
      },
      deleteComment: { filterID, commentID in
        try await httpClient.send(
          APIEndpoint<EmptyResponse>(router: FilterRouter.deleteComment(filterID: filterID, commentID: commentID))
        )
      }
    )
  }

  static let testValue = FilterClient(
    uploadFiles: { _ in throw APIError.transport("FilterClient.uploadFiles testValue") },
    create: { _ in throw APIError.transport("FilterClient.create testValue") },
    list: { _ in throw APIError.transport("FilterClient.list testValue") },
    detail: { _ in throw APIError.transport("FilterClient.detail testValue") },
    update: { _, _ in throw APIError.transport("FilterClient.update testValue") },
    delete: { _ in throw APIError.transport("FilterClient.delete testValue") },
    setLike: { _, _ in throw APIError.transport("FilterClient.setLike testValue") },
    userFilters: { _, _ in throw APIError.transport("FilterClient.userFilters testValue") },
    likedFilters: { _ in throw APIError.transport("FilterClient.likedFilters testValue") },
    hotTrend: { throw APIError.transport("FilterClient.hotTrend testValue") },
    todayFilter: { throw APIError.transport("FilterClient.todayFilter testValue") },
    createComment: { _, _ in throw APIError.transport("FilterClient.createComment testValue") },
    updateComment: { _, _, _ in throw APIError.transport("FilterClient.updateComment testValue") },
    deleteComment: { _, _ in throw APIError.transport("FilterClient.deleteComment testValue") }
  )
}

extension DependencyValues {
  var filterClient: FilterClient {
    get { self[FilterClient.self] }
    set { self[FilterClient.self] = newValue }
  }
}
