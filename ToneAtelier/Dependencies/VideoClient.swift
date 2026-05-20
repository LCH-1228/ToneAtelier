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
      .optional(name: "limit", value: limit)
    ]
      .compactMap { $0 }
  }
}

struct VideoClient {
  var list: @Sendable (_ query: VideoListQuery) async throws -> VideoListResponseDTO
  var fetchStream: @Sendable (_ videoID: String) async throws -> StreamUrlResponseDTO
  var setLike: @Sendable (_ videoID: String, _ likeStatus: Bool) async throws -> LikeStatusResponse
  /// stream_url / qualities[].url 처럼 토큰이 query에 박힌 짧은 path를 AVPlayer 가 바로 쓸 수 있는
  /// 절대 URL 로 변환. baseURL + APIInfo.Path.video + path 패턴(CommonRouter.fetchVideo 와 동일).
  /// HTTP 헤더 인증을 붙이지 않는 점만 다르다 — 명세상 토큰은 ?token=... 쿼리에 포함된다.
  var resolveStreamURL: @Sendable (_ rawURL: String) async throws -> URL
}

extension VideoClient: DependencyKey {
  static var liveValue: VideoClient {
    @Dependency(\.httpClient) var httpClient
    @Dependency(\.sessionClient) var sessionClient

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
      },
      resolveStreamURL: { rawURL in
        if let absolute = URL(string: rawURL), absolute.scheme != nil {
          return absolute
        }
        let session = await sessionClient.snapshot()
        let baseURL = session.configuration.baseURL
        // path 정규화는 VideoRouter.streamFile 에 위임. ?token=... 쿼리만 client 에서 보존한다.
        let routerPath = VideoRouter.streamFile(rawPath: rawURL).path
        let normalizedRouterPath = routerPath.hasPrefix("/") ? routerPath : "/\(routerPath)"
        let querySuffix: String
        if let queryStart = rawURL.firstIndex(of: "?") {
          querySuffix = String(rawURL[queryStart...])
        } else {
          querySuffix = ""
        }
        guard let resolved = URL(
          string: "\(normalizedRouterPath)\(querySuffix)",
          relativeTo: baseURL
        )?.absoluteURL else {
          throw APIError.invalidURL(rawURL)
        }
        return resolved
      }
    )
  }

  static let testValue = VideoClient(
    list: { _ in throw APIError.transport("VideoClient.list testValue") },
    fetchStream: { _ in throw APIError.transport("VideoClient.fetchStream testValue") },
    setLike: { _, _ in throw APIError.transport("VideoClient.setLike testValue") },
    resolveStreamURL: { _ in throw APIError.transport("VideoClient.resolveStreamURL testValue") }
  )
}

extension DependencyValues {
  var videoClient: VideoClient {
    get { self[VideoClient.self] }
    set { self[VideoClient.self] = newValue }
  }
}
