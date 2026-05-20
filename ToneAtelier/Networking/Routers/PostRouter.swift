//
//  PostRouter.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import Foundation

enum PostRouter: APIRouter {
  case uploadFiles([UploadFile])
  case create(PostRequestDTO)
  case listGeolocation(GeolocationPostsQuery)
  case search(title: String?)
  case detail(postID: String)
  case update(postID: String, PostUpdateRequestDTO)
  case delete(postID: String)
  case setLike(postID: String, status: Bool)
  case userPosts(userID: String, UserPostListQuery)
  case likedPosts(UserPostListQuery)
  case createComment(postID: String, CommentRequestDTO)
  case updateComment(postID: String, commentID: String, CommentUpdateRequestDTO)
  case deleteComment(postID: String, commentID: String)

  var method: HTTPMethod {
    switch self {
    case .uploadFiles, .create, .setLike, .createComment:
      return .post
    case .update, .updateComment:
      return .put
    case .delete, .deleteComment:
      return .delete
    case .listGeolocation, .search, .detail, .userPosts, .likedPosts:
      return .get
    }
  }

  var path: String {
    switch self {
    case .uploadFiles: return APIInfo.Path.postsFiles
    case .create: return APIInfo.Path.posts
    case .listGeolocation: return APIInfo.Path.postsGeolocation
    case .search: return APIInfo.Path.postsSearch
    case let .detail(postID): return "\(APIInfo.Path.posts)/\(postID)"
    case let .update(postID, _): return "\(APIInfo.Path.posts)/\(postID)"
    case let .delete(postID): return "\(APIInfo.Path.posts)/\(postID)"
    case let .setLike(postID, _): return "\(APIInfo.Path.posts)/\(postID)\(APIInfo.Path.like)"
    case let .userPosts(userID, _): return "\(APIInfo.Path.postsUsers)/\(userID)"
    case .likedPosts: return APIInfo.Path.postsLikesMe
    case let .createComment(postID, _): return "\(APIInfo.Path.posts)/\(postID)\(APIInfo.Path.comments)"
    case let .updateComment(postID, commentID, _):
      return "\(APIInfo.Path.posts)/\(postID)\(APIInfo.Path.comments)/\(commentID)"
    case let .deleteComment(postID, commentID):
      return "\(APIInfo.Path.posts)/\(postID)\(APIInfo.Path.comments)/\(commentID)"
    }
  }

  var queryItems: [URLQueryItem] {
    switch self {
    case let .listGeolocation(query): return query.queryItems
    case let .search(title): return [.optional(name: "title", value: title)].compactMap { $0 }
    case let .userPosts(_, query): return query.queryItems
    case let .likedPosts(query): return query.queryItems
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
