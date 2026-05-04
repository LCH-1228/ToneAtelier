//
//  ChatSocketClient.swift
//  ToneAtelier
//
//  Created by LCH on 4/29/26.
//

import ComposableArchitecture
import Foundation
import OSLog
import SocketIO

// MARK: - Public Event Type

/// ChatRoomFeature가 소비하는 소켓 이벤트.
/// SocketIO의 raw event 모델을 의도적으로 노출하지 않고 도메인 이벤트로만 노출한다.
enum ChatSocketEvent: Sendable, Equatable {
  case connected
  case disconnected
  case message(ChatMessage)
  /// 서버 socket error 메시지(인증/방 권한 등). 단계 3에서는 alert 표시까지만.
  case authError(String)
  case unknownError(String)
}

// MARK: - Dependency Client

struct ChatSocketClient {
  /// roomID에 대한 소켓 connect를 시작하고 도메인 이벤트 스트림을 반환한다.
  /// 동일 roomID로 재호출 시 기존 연결을 정리한 뒤 새 stream을 발급한다.
  ///
  /// 연결에 필요한 `baseURL`, `namespace`, `seSACKey`, `accessToken`은 호출부(reducer effect)에서
  /// main-actor 격리된 의존성을 조회한 뒤 값으로 전달한다.
  /// 이렇게 해야 actor `LiveChatSocketCenter` 내부에서 격리 위반 없이
  /// SocketIO 매니저를 구성할 수 있다.
  ///
  /// `namespace`는 `/chats-{roomID}` 형태이며 `manager.socket(forNamespace:)`로 사용된다.
  /// `baseURL`은 path가 비어있는 root URL(scheme://host:port)이어야 한다.
  var connect: @Sendable (
    _ roomID: String,
    _ baseURL: URL,
    _ namespace: String,
    _ seSACKey: String,
    _ accessToken: String
  ) async throws -> AsyncStream<ChatSocketEvent>
  /// roomID 해당 소켓을 끊고 stream을 종료한다.
  var disconnect: @Sendable (_ roomID: String) async -> Void
}

extension ChatSocketClient: DependencyKey {
  static var liveValue: ChatSocketClient {
    let center = LiveChatSocketCenter.shared

    return ChatSocketClient(
      connect: { roomID, baseURL, namespace, seSACKey, accessToken in
        try await center.connect(
          roomID: roomID,
          baseURL: baseURL,
          namespace: namespace,
          seSACKey: seSACKey,
          accessToken: accessToken
        )
      },
      disconnect: { roomID in
        await center.disconnect(roomID: roomID)
      }
    )
  }

  static let testValue = ChatSocketClient(
    connect: { _, _, _, _, _ in throw APIError.transport("ChatSocketClient.connect testValue") },
    disconnect: { _ in }
  )
}

extension DependencyValues {
  var chatSocketClient: ChatSocketClient {
    get { self[ChatSocketClient.self] }
    set { self[ChatSocketClient.self] = newValue }
  }
}

// MARK: - Live Center (actor)

/// roomID별 SocketIO 매니저/소켓을 보관하는 단일 actor.
/// `SocketManager`/`SocketIOClient`가 Sendable이 아니므로 actor 격리 안에서만 보관·접근한다.
private actor LiveChatSocketCenter {
  static let shared = LiveChatSocketCenter()

  private struct Connection {
    let manager: SocketManager
    let socket: SocketIOClient
    var continuation: AsyncStream<ChatSocketEvent>.Continuation
  }

  private var connections: [String: Connection] = [:]

  // 각 connect 마다 새로 생성되는 매니저는 reuse하지 않는다 — extraHeaders/URL이 달라질 수 있어
  // 동일 roomID라도 토큰 갱신 시점에 새 manager로 다시 만든다.

  func connect(
    roomID: String,
    baseURL: URL,
    namespace: String,
    seSACKey: String,
    accessToken: String
  ) async throws -> AsyncStream<ChatSocketEvent> {
    // 동일 roomID로 살아 있는 연결이 있으면 정리 후 재생성한다.
    if connections[roomID] != nil {
      await disconnectInternal(roomID: roomID)
    }

    // SocketIO Swift 16.x에서 `extraHeaders`는 polling handshake에만 적용되고
    // websocket 전환 후에는 무시된다. 명세는 "Headers에 SeSACKey/Authorization"이지만
    // 보수적으로 `connectParams`에도 동일 값을 함께 실어 query string으로 전달해
    // 서버가 어느 쪽이든 인증을 검증할 수 있게 한다.
    // 또한 `forceWebsockets(true)`를 제거해 polling → websocket 표준 업그레이드 흐름을 유지하면
    // polling 단계에서 헤더가 정상 적용된다.
    let manager = SocketManager(
      socketURL: baseURL,
      config: [
        .log(false),
        .compress,
        .reconnects(true),
        .extraHeaders([
          "SeSACKey": seSACKey,
          "Authorization": accessToken
        ]),
        .connectParams([
          "SeSACKey": seSACKey,
          "Authorization": accessToken
        ])
      ]
    )
    // 서버가 `/chats-{roomID}` namespace를 정의한다는 명세에 따라
    // root("/")가 아닌 해당 namespace에 직접 부착해야 `chat` 이벤트가 도달한다.
    let socket = manager.socket(forNamespace: namespace)

    let stream = AsyncStream<ChatSocketEvent>.makeStream(bufferingPolicy: .unbounded)
    let continuation = stream.continuation

    // termination 시 actor에 다시 진입해 정리.
    continuation.onTermination = { [weak self] _ in
      guard let self else { return }
      Task { await self.handleStreamTermination(roomID: roomID) }
    }

    bindEvents(
      socket: socket,
      roomID: roomID,
      namespace: namespace,
      continuation: continuation
    )

    connections[roomID] = Connection(
      manager: manager,
      socket: socket,
      continuation: continuation
    )

    socket.connect()

    let base = baseURL.absoluteString
    Logger.chatSocket.notice(
      "[ChatSocket] connect requested room=\(roomID, privacy: .public) base=\(base) ns=\(namespace, privacy: .public)"
    )

    return stream.stream
  }

  func disconnect(roomID: String) async {
    await disconnectInternal(roomID: roomID)
  }

  // MARK: - Private

  private func disconnectInternal(roomID: String) async {
    guard let connection = connections.removeValue(forKey: roomID) else { return }
    connection.socket.removeAllHandlers()
    connection.socket.disconnect()
    connection.continuation.finish()
    Logger.chatSocket.notice("[ChatSocket] disconnect room=\(roomID, privacy: .public)")
  }

  private func handleStreamTermination(roomID: String) async {
    // 컨슈머 측에서 stream 구독을 끊은 경우(View가 사라진 경우 등)에도 socket을 정리한다.
    guard let connection = connections.removeValue(forKey: roomID) else { return }
    connection.socket.removeAllHandlers()
    connection.socket.disconnect()
    Logger.chatSocket.debug(
      "[ChatSocket] cleaned up via stream termination room=\(roomID, privacy: .public)"
    )
  }

  /// SocketIO 핸들러는 메인 큐에서 호출된다. 핸들러 내부에서는 actor에 safe하게
  /// 격리된 작업이 필요하지 않으며, continuation.yield는 어느 컨텍스트에서나 안전하다.
  private func bindEvents(
    socket: SocketIOClient,
    roomID: String,
    namespace: String,
    continuation: AsyncStream<ChatSocketEvent>.Continuation
  ) {
    socket.on(clientEvent: .connect) { data, _ in
      let ack = String(describing: data.first)
      Logger.chatSocket.notice(
        "[ChatSocket] connected room=\(roomID, privacy: .public) ns=\(namespace, privacy: .public) ack=\(ack)"
      )
      continuation.yield(.connected)
    }

    socket.on(clientEvent: .disconnect) { data, _ in
      let reason = String(describing: data.first)
      Logger.chatSocket.notice(
        "[ChatSocket] disconnected room=\(roomID, privacy: .public) ns=\(namespace, privacy: .public) reason=\(reason)"
      )
      continuation.yield(.disconnected)
    }

    socket.on(clientEvent: .error) { data, _ in
      let message = Self.extractMessage(from: data) ?? "알 수 없는 소켓 오류"
      Logger.chatSocket.error(
        "[ChatSocket] error room=\(roomID, privacy: .public) ns=\(namespace, privacy: .public) message=\(message)"
      )
      // SocketIO `.error`는 인증 실패뿐 아니라 transport hiccup도 방출하므로
      // 알려진 인증/권한 메시지에만 authError로 분류하고 그 외에는 unknownError로 둔다.
      // (C4: 일시 끊김에도 alert이 뜨던 문제 보수화)
      continuation.yield(Self.classifyError(message: message))
    }

    // 진단용: status/upgrade/reconnect 등 lifecycle 이벤트 흔적을 OSLog에 남긴다.
    socket.on(clientEvent: .statusChange) { data, _ in
      let payload = String(describing: data)
      Logger.chatSocket.debug(
        "[ChatSocket] status room=\(roomID, privacy: .public) ns=\(namespace, privacy: .public) data=\(payload)"
      )
    }

    socket.on("chat") { data, _ in
      let raw = String(describing: data.first)
      Logger.chatSocket.debug(
        "[ChatSocket] chat room=\(roomID, privacy: .public) ns=\(namespace, privacy: .public) raw=\(raw)"
      )
      guard let payload = data.first as? [String: Any] else {
        continuation.yield(.unknownError("chat 이벤트 페이로드를 해석할 수 없습니다."))
        return
      }
      do {
        let json = try JSONSerialization.data(withJSONObject: payload, options: [])
        let message = try JSONDecoder().decode(ChatMessage.self, from: json)
        continuation.yield(.message(message))
      } catch {
        Logger.chatSocket.error(
          "[ChatSocket] decode failed room=\(roomID, privacy: .public): \(error.localizedDescription, privacy: .public)"
        )
        continuation.yield(.unknownError("메시지를 해석할 수 없습니다."))
      }
    }
  }

  private static func extractMessage(from data: [Any]) -> String? {
    if let first = data.first as? String, !first.isEmpty {
      return first
    }
    if let dict = data.first as? [String: Any] {
      if let message = dict["message"] as? String { return message }
      if let reason = dict["reason"] as? String { return reason }
    }
    return nil
  }

  /// 서버가 내려주는 알려진 인증/권한 관련 문구는 authError로 분류해 alert으로 노출하고,
  /// 그 외 transport 단위 hiccup 메시지는 unknownError로 분류한다.
  /// 부분 일치(contains)로 검사하며, 새 케이스가 발견되면 본 배열에 추가한다.
  private static func classifyError(message: String) -> ChatSocketEvent {
    let knownAuthSubstrings = [
      "sesac_memolease",
      "액세스 토큰",
      "엑세스 토큰",
      "Forbidden",
      "Invalid namespace",
      "채팅방을 찾을 수 없습니다",
      "채팅방 참여자가 아닙니다"
    ]
    if knownAuthSubstrings.contains(where: { message.contains($0) }) {
      return .authError(message)
    }
    return .unknownError(message)
  }
}

// MARK: - Logger

extension Logger {
  fileprivate nonisolated static let chatSocket = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.mitti.ToneAtelier",
    category: "ChatSocket"
  )
}
