//
//  AuthenticatedAssetLoader.swift
//  ToneAtelier
//

import AVFoundation
import ComposableArchitecture
import Foundation
import OSLog

/// AVPlayer 가 보내는 byte-range request 를 가로채 인증 헤더 부착 + URLSession 으로 직접 fetch.
/// 401/403 시 1회 retry — 다른 API 가 그 사이 토큰 갱신했을 가능성에 대응.
/// 사용 — AVURLAsset url 의 scheme 을 "auth+https" 로 변경 후 setDelegate.
final class AuthenticatedAssetLoader: NSObject, @unchecked Sendable {
  /// 원본 URL 의 scheme 을 그대로 보존하면서 prefix 만 붙여 AVPlayer 가 unknown scheme 으로 인식하게 한다.
  /// 예: "http://server/x" → "auth+http://server/x", "https://server/x" → "auth+https://server/x".
  static let schemePrefix = "auth+"

  /// 원본 URL 에 prefix 를 붙여 custom URL 생성.
  static func customURL(from originalURL: URL) -> URL {
    let absolute = originalURL.absoluteString
    return URL(string: schemePrefix + absolute) ?? originalURL
  }

  private let sessionClient: SessionClient
  let delegateQueue = DispatchQueue(label: "AuthenticatedAssetLoader.delegate")
  private let sessionQueue = DispatchQueue(label: "AuthenticatedAssetLoader.sessionQueue")
  private var activeTasks: [ObjectIdentifier: Task<Void, Never>] = [:]
  private let urlSession: URLSession = {
    let config = URLSessionConfiguration.default
    config.networkServiceType = .video
    config.requestCachePolicy = .reloadIgnoringLocalCacheData
    config.waitsForConnectivity = false
    return URLSession(configuration: config)
  }()

  init(sessionClient: SessionClient) {
    self.sessionClient = sessionClient
    super.init()
  }

  func resourceLoader(
    _ resourceLoader: AVAssetResourceLoader,
    shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
  ) -> Bool {
    let id = ObjectIdentifier(loadingRequest)
    let request = loadingRequest.request
    let dataRequest = loadingRequest.dataRequest
    let contentInfo = loadingRequest.contentInformationRequest
    let task = Task { [weak self] in
      await self?.handle(
        loadingRequest: loadingRequest,
        request: request,
        dataRequest: dataRequest,
        contentInfo: contentInfo
      )
      self?.sessionQueue.async {
        self?.activeTasks.removeValue(forKey: id)
      }
    }
    sessionQueue.async { [weak self] in
      self?.activeTasks[id] = task
    }
    return true
  }

  func resourceLoader(
    _ resourceLoader: AVAssetResourceLoader,
    didCancel loadingRequest: AVAssetResourceLoadingRequest
  ) {
    let id = ObjectIdentifier(loadingRequest)
    sessionQueue.async { [weak self] in
      if let task = self?.activeTasks.removeValue(forKey: id) {
        task.cancel()
      }
    }
  }

  private func handle(
    loadingRequest: AVAssetResourceLoadingRequest,
    request originalRequest: URLRequest,
    dataRequest: AVAssetResourceLoadingDataRequest?,
    contentInfo: AVAssetResourceLoadingContentInformationRequest?
  ) async {
    guard let url = originalRequest.url else {
      loadingRequest.finishLoading(with: APIError.invalidURL("AuthenticatedAssetLoader"))
      return
    }
    let actualURL = Self.restoreOriginalURL(from: url)
    Logger.videoPlayer.notice(
      "asset loader fetch — url=\(actualURL.absoluteString, privacy: .private)"
    )

    for attempt in 0..<2 {
      do {
        let session = await sessionClient.snapshot()
        var request = URLRequest(url: actualURL)
        if !session.accessToken.trimmed.isEmpty {
          request.setValue(
            session.accessToken.trimmed,
            forHTTPHeaderField: APIInfo.HeaderField.authorization
          )
        }
        if !session.configuration.seSACKey.trimmed.isEmpty {
          request.setValue(
            session.configuration.seSACKey.trimmed,
            forHTTPHeaderField: APIInfo.HeaderField.seSACKey
          )
        }
        if let dataRequest {
          let start = dataRequest.requestedOffset
          let length = Int64(dataRequest.requestedLength)
          let end = start + length - 1
          request.setValue("bytes=\(start)-\(end)", forHTTPHeaderField: "Range")
        }

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
          throw APIError.transport("AuthenticatedAssetLoader missing HTTPURLResponse")
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403, attempt == 0 {
          Logger.videoPlayer.notice(
            "asset loader 401/403 — retry once after 300ms"
          )
          try? await Task.sleep(nanoseconds: 300_000_000)
          continue
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
          throw APIError.server(statusCode: httpResponse.statusCode, message: nil, rawBody: nil)
        }

        Logger.videoPlayer.notice("""
          asset loader response — \
          status=\(httpResponse.statusCode, privacy: .public) \
          bytes=\(data.count, privacy: .public) \
          range=\(httpResponse.value(forHTTPHeaderField: "Content-Range") ?? "-", privacy: .public)
          """)

        if let contentInfo {
          contentInfo.contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")
          contentInfo.contentLength = Self.totalLength(from: httpResponse) ?? Int64(data.count)
          let acceptRanges = httpResponse.value(forHTTPHeaderField: "Accept-Ranges")
          contentInfo.isByteRangeAccessSupported = acceptRanges?.lowercased() == "bytes"
            || httpResponse.statusCode == 206
        }

        if let dataRequest {
          if httpResponse.statusCode == 206 {
            // Range 응답 — body 가 정확히 요청 영역. 그대로 응답.
            dataRequest.respond(with: data)
          } else {
            // 200 응답 — 서버가 Range 미지원으로 전체 body 반환. dataRequest 영역만 slice.
            let start = Int(dataRequest.requestedOffset)
            let length = dataRequest.requestedLength
            if start < data.count {
              let end = min(start + length, data.count)
              dataRequest.respond(with: data.subdata(in: start..<end))
            }
          }
        }
        loadingRequest.finishLoading()
        return
      } catch is CancellationError {
        return
      } catch {
        if attempt == 0 {
          Logger.videoPlayer.notice("asset loader error attempt=0, retrying once")
          try? await Task.sleep(nanoseconds: 300_000_000)
          continue
        }
        Logger.videoPlayer.error(
          "asset loader failed after retry: \(error.localizedDescription, privacy: .private)"
        )
        loadingRequest.finishLoading(with: error)
        return
      }
    }
  }

  private static func restoreOriginalURL(from url: URL) -> URL {
    let absolute = url.absoluteString
    guard absolute.hasPrefix(schemePrefix) else { return url }
    return URL(string: String(absolute.dropFirst(schemePrefix.count))) ?? url
  }

  private static func totalLength(from response: HTTPURLResponse) -> Int64? {
    if let contentRange = response.value(forHTTPHeaderField: "Content-Range"),
       let slash = contentRange.lastIndex(of: "/") {
      let total = contentRange[contentRange.index(after: slash)...]
      if total != "*", let parsed = Int64(total) {
        return parsed
      }
    }
    let expected = response.expectedContentLength
    return expected == NSURLSessionTransferSizeUnknown ? nil : expected
  }
}

extension AuthenticatedAssetLoader: AVAssetResourceLoaderDelegate {}
