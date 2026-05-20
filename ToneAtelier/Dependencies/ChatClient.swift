//
//  ChatClient.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import ComposableArchitecture
import Foundation

struct CreateChatRoomRequest: Encodable, Equatable, Sendable {
  let opponentID: String

  enum CodingKeys: String, CodingKey {
    case opponentID = "opponent_id"
  }
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

/// SocketIO 연결 좌표.
/// 명세 `http://{baseURL}:{port}/chats-{room_id}` 에서 `/chats-{room_id}` 부분은
/// SocketIO **namespace**이다(서버가 `io.of("/chats-...")`로 정의).
/// 따라서 `SocketManager(socketURL:)`에는 baseURL만 전달하고 namespace는
/// `manager.socket(forNamespace:)`로 분리 전달해야 서버 측 `chat` 이벤트가 도달한다.
nonisolated struct ChatSocketConnection: Sendable, Equatable {
  /// baseURL — `SocketManager(socketURL:)`에 그대로 전달한다(scheme://host:port).
  let baseURL: URL
  /// SocketIO namespace — `/chats-{roomID}` 형태. `manager.socket(forNamespace:)`로 사용.
  let namespace: String
}

struct ChatSocketConnectionBuilder {
  func build(roomID: String, configuration: APIConfiguration) throws -> ChatSocketConnection {
    // baseURL의 path/query/fragment를 모두 비워 host(+port)까지의 URL만 남긴다.
    // SocketIO Swift에서 SocketManager(socketURL:)에는 root URL을 전달하는 것이 표준이며,
    // 이 URL에 path가 박혀 있으면 root namespace 핸드셰이크가 그 path 위에서 일어나
    // namespace 분기와 충돌할 수 있다.
    guard var components = URLComponents(
      url: configuration.baseURL,
      resolvingAgainstBaseURL: false
    ) else {
      throw APIError.invalidBaseURL(configuration.baseURL.absoluteString)
    }

    components.percentEncodedPath = ""
    components.query = nil
    components.fragment = nil

    guard let baseURL = components.url else {
      throw APIError.invalidBaseURL(configuration.baseURL.absoluteString)
    }

    let namespace = "\(APIInfo.Path.chatsSocketPrefix)\(roomID)"
    return ChatSocketConnection(baseURL: baseURL, namespace: namespace)
  }
}

struct ChatClient {
  var createRoom: @Sendable (_ request: CreateChatRoomRequest) async throws -> ChatRoom
  var listRooms: @Sendable () async throws -> ChatRoomListResponse
  var sendMessage: @Sendable (_ roomID: String, _ request: SendChatRequest) async throws -> ChatMessage
  var listMessages: @Sendable (_ roomID: String, _ query: ChatHistoryQuery) async throws -> ChatMessageListResponse
  var uploadFiles: @Sendable (_ roomID: String, _ files: [UploadFile]) async throws -> UploadedFilesResponse
  /// roomID에 대한 Socket 연결 좌표(baseURL + namespace)를 반환한다.
  /// 단일 `URL`에 path를 박는 구조에서 분리되었다(C1 fix).
  var socketConnection: @Sendable (_ roomID: String) async throws -> ChatSocketConnection
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
      socketConnection: { roomID in
        let snapshot = await sessionClient.snapshot()
        return try await ChatSocketConnectionBuilder().build(
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
    socketConnection: { _ in throw APIError.transport("ChatClient.socketConnection testValue") }
  )
}

extension DependencyValues {
  var chatClient: ChatClient {
    get { self[ChatClient.self] }
    set { self[ChatClient.self] = newValue }
  }
}
