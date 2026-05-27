//
//  CommonClient.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import ComposableArchitecture
import Foundation

struct WebViewRequest: Equatable, Sendable {
  let url: URL
  let headers: [String: String]
}

enum ImageFetchResult: Equatable, Sendable {
  case fresh(Data, eTag: String?)
  case notModified
}

struct CommonClient {
  var fetchLogs: @Sendable () async throws -> LogsResponse
  var fetchPhoto: @Sendable (_ path: String, _ ifNoneMatch: String?) async throws -> ImageFetchResult
  var fetchVideo: @Sendable (_ path: String) async throws -> Data
  var fetchSubtitle: @Sendable (_ path: String) async throws -> Data
  var makeVideoRequest: @Sendable (_ path: String) async throws -> WebViewRequest
  var makeWebViewRequest: @Sendable (_ path: String) async throws -> WebViewRequest
}

extension CommonClient: DependencyKey {
  static var liveValue: CommonClient {
    @Dependency(\.httpClient) var httpClient
    @Dependency(\.sessionClient) var sessionClient

    return CommonClient(
      fetchLogs: {
        try await httpClient.send(
          APIEndpoint<LogsResponse>(router: CommonRouter.fetchLogs)
        )
      },
      fetchPhoto: { path, ifNoneMatch in
        let router = CommonRouter.fetchPhoto(path)
        var headers = router.headers
        if let ifNoneMatch {
          headers["If-None-Match"] = ifNoneMatch
        }
        return try await httpClient.send(
          APIEndpoint<ImageFetchResult>(
            method: router.method,
            path: router.path,
            queryItems: router.queryItems,
            headers: headers,
            body: router.body,
            requiresAccessToken: router.requiresAccessToken,
            requiresRefreshToken: router.requiresRefreshToken,
            allowsNotModified: true
          ) { data, response, _ in
            if response.statusCode == 304 {
              return .notModified
            }
            let etag = response.value(forHTTPHeaderField: "ETag")
            return .fresh(data, eTag: etag)
          }
        )
      },
      fetchVideo: { path in
        let router = CommonRouter.fetchVideo(path)

        return try await httpClient.send(
          APIEndpoint<Data>(
            method: router.method,
            path: router.path,
            queryItems: router.queryItems,
            headers: router.headers,
            body: router.body,
            requiresAccessToken: router.requiresAccessToken,
            requiresRefreshToken: router.requiresRefreshToken
          ) { data, _, _ in
            data
          }
        )
      },
      fetchSubtitle: { path in
        let router = CommonRouter.fetchSubtitle(path)

        return try await httpClient.send(
          APIEndpoint<Data>(
            method: router.method,
            path: router.path,
            queryItems: router.queryItems,
            headers: router.headers,
            body: router.body,
            requiresAccessToken: router.requiresAccessToken,
            requiresRefreshToken: router.requiresRefreshToken
          ) { data, _, _ in
            data
          }
        )
      },
      makeVideoRequest: { path in
        let session = await sessionClient.snapshot()
        let router = CommonRouter.fetchVideo(path)
        let request = try URLRequestBuilder().build(
          for: APIEndpoint<EmptyResponse>(
            method: router.method,
            path: router.path,
            queryItems: router.queryItems,
            headers: router.headers,
            body: router.body,
            requiresAccessToken: router.requiresAccessToken,
            requiresRefreshToken: router.requiresRefreshToken
          ),
          session: session
        )

        guard let url = request.url else {
          throw APIError.invalidURL(path)
        }

        return WebViewRequest(
          url: url,
          headers: request.allHTTPHeaderFields ?? [:]
        )
      },
      makeWebViewRequest: { path in
        let session = await sessionClient.snapshot()
        let router = CommonRouter.webView(path)
        let request = try URLRequestBuilder().build(
          for: APIEndpoint<EmptyResponse>(
            method: router.method,
            path: router.path,
            queryItems: router.queryItems,
            headers: router.headers,
            body: router.body,
            requiresAccessToken: router.requiresAccessToken,
            requiresRefreshToken: router.requiresRefreshToken
          ),
          session: session
        )

        guard let url = request.url else {
          throw APIError.invalidURL(path)
        }

        return WebViewRequest(
          url: url,
          headers: request.allHTTPHeaderFields ?? [:]
        )
      }
    )
  }

  static let testValue = CommonClient(
    fetchLogs: {
      throw APIError.transport("CommonClient.fetchLogs testValue")
    },
    fetchPhoto: { _, _ in
      throw APIError.transport("CommonClient.fetchPhoto testValue")
    },
    fetchVideo: { _ in
      throw APIError.transport("CommonClient.fetchVideo testValue")
    },
    fetchSubtitle: { _ in
      throw APIError.transport("CommonClient.fetchSubtitle testValue")
    },
    makeVideoRequest: { _ in
      throw APIError.transport("CommonClient.makeVideoRequest testValue")
    },
    makeWebViewRequest: { _ in
      throw APIError.transport("CommonClient.makeWebViewRequest testValue")
    }
  )
}

extension DependencyValues {
  var commonClient: CommonClient {
    get { self[CommonClient.self] }
    set { self[CommonClient.self] = newValue }
  }
}
