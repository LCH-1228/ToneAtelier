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

  var method: HTTPMethod {
    switch self {
    case .list, .fetchStream:
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

  var requiresAccessToken: Bool { true }
}
