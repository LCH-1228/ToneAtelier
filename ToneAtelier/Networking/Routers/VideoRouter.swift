//
//  VideoRouter.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import Foundation

enum VideoRouter: APIRouter {
  case list(VideoListQuery)
  case fetchStream(videoID: String)
  case setLike(videoID: String, status: Bool)
  /// HLS master/segment 파일을 AVPlayer 가 직접 fetch 하기 위한 path 빌드 전용 case.
  /// HTTPClient.send 로 호출되지 않으며, VideoClient.resolveStreamURL 에서 path 만 사용한다.
  /// 명세상 토큰은 ?token=... 쿼리에 포함되므로 access token 헤더는 붙이지 않는다.
  case streamFile(rawPath: String)

  var method: HTTPMethod {
    switch self {
    case .list, .fetchStream, .streamFile:
      return .get
    case .setLike:
      return .post
    }
  }

  var path: String {
    switch self {
    case .list: return APIInfo.Path.videos
    case let .fetchStream(videoID): return "\(APIInfo.Path.videos)/\(videoID)\(APIInfo.Path.stream)"
    case let .setLike(videoID, _): return "\(APIInfo.Path.videos)/\(videoID)\(APIInfo.Path.like)"
    case let .streamFile(rawPath):
      // ?token=... 쿼리는 client 단에서 보존한다. 여기서는 path 정규화만 담당.
      let pathOnly = rawPath.split(separator: "?", maxSplits: 1).first.map(String.init) ?? rawPath
      let normalized = pathOnly.hasPrefix("/") ? String(pathOnly.dropFirst()) : pathOnly
      return "\(APIInfo.Path.video)/\(normalized)"
    }
  }

  var queryItems: [URLQueryItem] {
    switch self {
    case let .list(query): return query.queryItems
    default: return []
    }
  }

  var body: HTTPBody {
    get throws {
      switch self {
      case let .setLike(_, status): return try .jsonBody(LikeStatusRequest(likeStatus: status))
      default: return .none
      }
    }
  }

  var requiresAccessToken: Bool {
    switch self {
    case .streamFile: return false
    default: return true
    }
  }
}
