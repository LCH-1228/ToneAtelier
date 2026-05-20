//
//  ChatRouter.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import Foundation

enum ChatRouter: APIRouter {
  case createRoom(CreateChatRoomRequest)
  case listRooms
  case sendMessage(roomID: String, SendChatRequest)
  case listMessages(roomID: String, ChatHistoryQuery)
  case uploadFiles(roomID: String, [UploadFile])

  var method: HTTPMethod {
    switch self {
    case .createRoom, .sendMessage, .uploadFiles:
      return .post
    case .listRooms, .listMessages:
      return .get
    }
  }

  var path: String {
    switch self {
    case .createRoom, .listRooms: return APIInfo.Path.chats
    case let .sendMessage(roomID, _): return "\(APIInfo.Path.chats)/\(roomID)"
    case let .listMessages(roomID, _): return "\(APIInfo.Path.chats)/\(roomID)"
    case let .uploadFiles(roomID, _): return "\(APIInfo.Path.chats)/\(roomID)\(APIInfo.Path.files)"
    }
  }

  var queryItems: [URLQueryItem] {
    switch self {
    case let .listMessages(_, query): return query.queryItems
    default: return []
    }
  }

  var body: HTTPBody {
    get throws {
      switch self {
      case let .createRoom(request): return try .jsonBody(request)
      case let .sendMessage(_, request): return try .jsonBody(request)
      case let .uploadFiles(_, files):
        let parts = files.map { file in
          MultipartFormData.Part.file(
            UploadFile(fieldName: "files", fileName: file.fileName, mimeType: file.mimeType, data: file.data)
          )
        }
        return .multipart(MultipartFormData(parts: parts))
      default: return .none
      }
    }
  }

  var requiresAccessToken: Bool { true }
}
