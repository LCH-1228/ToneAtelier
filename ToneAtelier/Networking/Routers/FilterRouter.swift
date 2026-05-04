//
//  FilterRouter.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import Foundation

enum FilterRouter: APIRouter {
  case uploadFiles([UploadFile])
  case create(FilterRequestDTO)
  case list(FilterListQuery)
  case detail(filterID: String)
  case update(filterID: String, FilterUpdateRequestDTO)
  case delete(filterID: String)
  case setLike(filterID: String, status: Bool)
  case userFilters(userID: String, UserFilterListQuery)
  case likedFilters(UserFilterListQuery)
  case hotTrend
  case todayFilter
  case createComment(filterID: String, CommentRequestDTO)
  case updateComment(filterID: String, commentID: String, CommentUpdateRequestDTO)
  case deleteComment(filterID: String, commentID: String)

  var method: HTTPMethod {
    switch self {
    case .uploadFiles, .create, .setLike, .createComment:
      return .post
    case .update, .updateComment:
      return .put
    case .delete, .deleteComment:
      return .delete
    case .list, .detail, .userFilters, .likedFilters, .hotTrend, .todayFilter:
      return .get
    }
  }

  var path: String {
    switch self {
    case .uploadFiles: return APIInfo.Path.filtersFiles
    case .create, .list: return APIInfo.Path.filters
    case let .detail(filterID): return "\(APIInfo.Path.filters)/\(filterID)"
    case let .update(filterID, _): return "\(APIInfo.Path.filters)/\(filterID)"
    case let .delete(filterID): return "\(APIInfo.Path.filters)/\(filterID)"
    case let .setLike(filterID, _): return "\(APIInfo.Path.filters)/\(filterID)\(APIInfo.Path.like)"
    case let .userFilters(userID, _): return "\(APIInfo.Path.filtersUsers)/\(userID)"
    case .likedFilters: return APIInfo.Path.filtersLikesMe
    case .hotTrend: return APIInfo.Path.filtersHotTrend
    case .todayFilter: return APIInfo.Path.filtersTodayFilter
    case let .createComment(filterID, _): return "\(APIInfo.Path.filters)/\(filterID)\(APIInfo.Path.comments)"
    case let .updateComment(filterID, commentID, _):
      return "\(APIInfo.Path.filters)/\(filterID)\(APIInfo.Path.comments)/\(commentID)"
    case let .deleteComment(filterID, commentID):
      return "\(APIInfo.Path.filters)/\(filterID)\(APIInfo.Path.comments)/\(commentID)"
    }
  }

  var queryItems: [URLQueryItem] {
    switch self {
    case let .list(query): return query.queryItems
    case let .userFilters(_, query): return query.queryItems
    case let .likedFilters(query): return query.queryItems
    default: return []
    }
  }

  var body: HTTPBody {
    get throws {
      switch self {
      case let .uploadFiles(files):
        let parts = files.map { file in
          MultipartFormData.Part.file(
            UploadFile(fieldName: "files", fileName: file.fileName, mimeType: file.mimeType, data: file.data)
          )
        }
        return .multipart(MultipartFormData(parts: parts))
      case let .create(request): return try .jsonBody(request)
      case let .update(_, request): return try .jsonBody(request)
      case let .setLike(_, status): return try .jsonBody(LikeStatusRequest(likeStatus: status))
      case let .createComment(_, request): return try .jsonBody(request)
      case let .updateComment(_, _, request): return try .jsonBody(request)
      default: return .none
      }
    }
  }

  var requiresAccessToken: Bool { true }
}
