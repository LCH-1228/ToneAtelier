//
//  VideoClient.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import ComposableArchitecture
import Foundation

// MARK: - Query

struct VideoListQuery: Equatable, Sendable {
  var next: String?
  var limit: Int?

  var queryItems: [URLQueryItem] {
    [
      .optional(name: "next", value: next),
      .optional(name: "limit", value: limit),
    ]
      .compactMap { $0 }
  }
}

struct VideoClient {
  var list: @Sendable (_ query: VideoListQuery) async throws -> VideoListResponseDTO
  var fetchStream: @Sendable (_ videoID: String) async throws -> StreamUrlResponseDTO
  var setLike: @Sendable (_ videoID: String, _ likeStatus: Bool) async throws -> LikeStatusResponse
}

extension VideoClient: DependencyKey {
  static var liveValue: VideoClient {
    @Dependency(\.httpClient) var httpClient

    return VideoClient(
      list: { query in
        try await httpClient.send(
          APIEndpoint<VideoListResponseDTO>(router: VideoRouter.list(query))
        )
      },
      fetchStream: { videoID in
        try await httpClient.send(
          APIEndpoint<StreamUrlResponseDTO>(router: VideoRouter.fetchStream(videoID: videoID))
        )
      },
      setLike: { videoID, likeStatus in
        try await httpClient.send(
          APIEndpoint<LikeStatusResponse>(router: VideoRouter.setLike(videoID: videoID, status: likeStatus))
        )
      }
    )
  }

  static let testValue = VideoClient(
    list: { _ in throw APIError.transport("VideoClient.list testValue") },
    fetchStream: { _ in throw APIError.transport("VideoClient.fetchStream testValue") },
    setLike: { _, _ in throw APIError.transport("VideoClient.setLike testValue") }
  )
}

extension DependencyValues {
  var videoClient: VideoClient {
    get { self[VideoClient.self] }
    set { self[VideoClient.self] = newValue }
  }
}
