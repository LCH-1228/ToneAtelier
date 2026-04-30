//
//  ChatClient.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import ComposableArchitecture
import Foundation

struct CreateChatRoomRequest: Encodable, Equatable, Sendable {
  let opponent_id: String
}

struct SendChatRequest: Encodable, Equatable, Sendable {
  let content: String?
  let files: [String]?
}

struct ChatHistoryQuery: Equatable, Sendable {
  var next: String?

  var queryItems: [URLQueryItem] {
    [
      .optional(name: "next", value: next)
    ]
      .compactMap { $0 }
  }
}

struct ChatSocketURLBuilder {
  func build(roomID: String, configuration: APIConfiguration) throws -> URL {
    guard var components = URLComponents(
      url: configuration.baseURL,
      resolvingAgainstBaseURL: false
    ) else {
      throw APIError.invalidBaseURL(configuration.baseURL.absoluteString)
    }

    components.query = nil
    components.fragment = nil
    components.percentEncodedPath = "\(APIInfo.Path.chatsSocketPrefix)\(roomID)"

    guard let url = components.url else {
      throw APIError.invalidURL("\(APIInfo.Path.chatsSocketPrefix)\(roomID)")
    }

    return url
  }
}

struct ChatClient {
  var createRoom: @Sendable (_ request: CreateChatRoomRequest) async throws -> ChatRoom
  var listRooms: @Sendable () async throws -> ChatRoomListResponse
  var sendMessage: @Sendable (_ roomID: String, _ request: SendChatRequest) async throws -> ChatMessage
  var listMessages: @Sendable (_ roomID: String, _ query: ChatHistoryQuery) async throws -> ChatMessageListResponse
  var uploadFiles: @Sendable (_ roomID: String, _ files: [UploadFile]) async throws -> UploadedFilesResponse
  var socketURL: @Sendable (_ roomID: String) async throws -> URL
}

extension ChatClient: DependencyKey {
  static var liveValue: ChatClient {
    @Dependency(\.httpClient) var httpClient
    @Dependency(\.sessionClient) var sessionClient

    return ChatClient(
      createRoom: { request in
        try await httpClient.send(
          APIEndpoint<ChatRoom>(router: ChatRouter.createRoom(request))
        )
      },
      listRooms: {
        try await httpClient.send(
          APIEndpoint<ChatRoomListResponse>(router: ChatRouter.listRooms)
        )
      },
      sendMessage: { roomID, request in
        try await httpClient.send(
          APIEndpoint<ChatMessage>(router: ChatRouter.sendMessage(roomID: roomID, request))
        )
      },
      listMessages: { roomID, query in
        try await httpClient.send(
          APIEndpoint<ChatMessageListResponse>(router: ChatRouter.listMessages(roomID: roomID, query))
        )
      },
      uploadFiles: { roomID, files in
        try await httpClient.send(
          APIEndpoint<UploadedFilesResponse>(router: ChatRouter.uploadFiles(roomID: roomID, files))
        )
      },
      socketURL: { roomID in
        let snapshot = await sessionClient.snapshot()
        return try await ChatSocketURLBuilder().build(
          roomID: roomID,
          configuration: snapshot.configuration
        )
      }
    )
  }

  static let testValue = ChatClient(
    createRoom: { _ in throw APIError.transport("ChatClient.createRoom testValue") },
    listRooms: { throw APIError.transport("ChatClient.listRooms testValue") },
    sendMessage: { _, _ in throw APIError.transport("ChatClient.sendMessage testValue") },
    listMessages: { _, _ in throw APIError.transport("ChatClient.listMessages testValue") },
    uploadFiles: { _, _ in throw APIError.transport("ChatClient.uploadFiles testValue") },
    socketURL: { _ in throw APIError.transport("ChatClient.socketURL testValue") }
  )
}

extension DependencyValues {
  var chatClient: ChatClient {
    get { self[ChatClient.self] }
    set { self[ChatClient.self] = newValue }
  }
}
