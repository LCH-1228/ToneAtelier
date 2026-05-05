//
//  ChatRoomFeature.swift
//  ToneAtelier
//
//  Created by LCH on 4/29/26.
//

// swiftlint:disable file_length
// 채팅방은 reducer 본체 + 첨부 모델 + 소켓 lifecycle + dedup helper가 한 도메인 단위라
// 외부로 분리해도 의미 있는 경계가 생기지 않아 같은 파일 유지.

import ComposableArchitecture
import Foundation

// MARK: - Local Attachment

/// 전송 대기 중인 첨부 파일. 이미지(PhotosPicker) 또는 PDF(fileImporter)로 채워진다.
/// 즉시 미리보기를 위해 raw `Data`를 보관하며, 실제 업로드 시점에 `UploadFile`로 변환한다.
///
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` 환경에서 effect closure(@Sendable)
/// 안에서 `toUploadFile()`을 호출할 수 있도록 타입 전체를 `nonisolated`로 선언한다.
nonisolated struct LocalAttachment: Equatable, Identifiable, Sendable {
  enum Kind: String, Equatable, Sendable {
    case image
    case pdf
  }

  let id: UUID
  let kind: Kind
  let fileName: String
  let mimeType: String
  let data: Data
  let previewImage: Data?

  func toUploadFile() -> UploadFile {
    UploadFile(
      fieldName: "files",
      fileName: fileName,
      mimeType: mimeType,
      data: data
    )
  }
}

// MARK: - Reducer

@Reducer
// swiftlint:disable:next type_body_length
struct ChatRoomFeature {
  /// 첨부 최대 개수. 명세 기준값.
  static let maxAttachments = 5
  /// 단일 첨부 최대 크기(바이트). 5MB.
  static let maxAttachmentBytes = 5 * 1024 * 1024

  @ObservableState
  struct State: Equatable {
    let roomID: String
    /// 부모(ChatTabFeature)에서 주입. 헤더 표시용. 없으면 history sender로 대체.
    let opponent: ChatUserSummary?

    var currentUserID: String?
    var baseURL: URL?

    var messages: IdentifiedArrayOf<ChatMessage> = []
    var inputText: String = ""
    var attachments: [LocalAttachment] = []

    var isLoadingHistory = false
    var isSending = false
    var hasSyncedOnce = false

    /// 풀스크린 PDF 미리보기 대상 파일 URL. nil이면 미리보기 숨김.
    var previewingURL: URL?
    /// 진행 중인 PDF 미리보기 파일 fetch의 path. 셀의 도넛 progress 표시 + 동시 다중 진행 방지 용도.
    var preparingPreviewPath: String?

    @Presents var alert: AlertState<Action.Alert>?

    init(roomID: String, opponent: ChatUserSummary? = nil) {
      self.roomID = roomID
      self.opponent = opponent
    }

    var canSend: Bool {
      guard !isSending else { return false }
      let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
      return !trimmed.isEmpty || !attachments.isEmpty
    }

    /// 헤더/메시지 셀에서 표시할 상대방 후보. opponent가 주입되지 않은 경우
    /// 메시지 senders에서 currentUserID와 다른 첫 sender를 사용한다.
    var displayOpponent: ChatUserSummary? {
      if let opponent { return opponent }
      guard let currentUserID else { return messages.first?.sender }
      return messages.first(where: { $0.sender.userID != currentUserID })?.sender
    }
  }

  enum Action: BindableAction, Sendable {
    case binding(BindingAction<State>)
    case task
    case onDisappear
    case bootstrapResponse(currentUserID: String?, baseURL: URL?)
    case localCacheLoaded([ChatMessage])
    case historyResponse(Result<[ChatMessage], Error>)
    case socketEvent(ChatSocketEvent)
    case sendTapped
    case sendResponse(Result<ChatMessage, Error>)
    case attachmentsAdded([LocalAttachment])
    case attachmentRemoveTapped(UUID)
    case attachmentLoadFailed(message: String)
    case pdfPreviewTapped(path: String)
    case pdfPreviewURLPrepared(Result<URL, Error>, path: String)
    case pdfPreviewDismissed
    case deleteRoomTapped
    case alert(PresentationAction<Alert>)
    case delegate(Delegate)

    enum Alert: Equatable, Sendable {
      case dismiss
      case confirmDelete
    }

    /// 채팅방에서 부모(ChatTab)에게 전달하는 도메인 이벤트.
    /// `ChatList`가 즉시 갱신될 수 있도록 `messageHandled`를 발신한다.
    enum Delegate: Equatable, Sendable {
      /// 메시지 송수신(소켓 수신/직접 전송)이 처리되어 lastChat/정렬이 변할 가능성이 있다.
      case messageHandled
      /// 채팅방을 로컬에서 삭제했다. 부모가 path 의 chatRoom element 를 pop 한다.
      case deleted
    }
  }

  @Dependency(\.chatClient) private var chatClient
  @Dependency(\.chatLocalStore) private var chatLocalStore
  @Dependency(\.chatSocketClient) private var chatSocketClient
  @Dependency(\.currentChatRoomClient) private var currentChatRoomClient
  @Dependency(\.imageClient) private var imageClient
  @Dependency(\.sessionClient) private var sessionClient

  var body: some Reducer<State, Action> {
    BindingReducer()

    Reduce { state, action in
      switch action {
      case .binding:
        return .none

      case .task:
        return handleTaskAction(state: &state)

      case .onDisappear:
        let roomID = state.roomID
        let chatSocketClient = chatSocketClient
        let currentChatRoomClient = currentChatRoomClient
        // 진행 중인 PDF 미리보기 fetch가 있다면 함께 정리.
        let preparingPath = state.preparingPreviewPath
        var effects: [Effect<Action>] = [
          .cancel(id: ChatRoomCancelID.bootstrap(roomID)),
          .cancel(id: ChatRoomCancelID.send(roomID)),
          .run { _ in
            await chatSocketClient.disconnect(roomID)
          },
          .run { _ in
            await currentChatRoomClient.clearIfMatching(roomID)
          }
        ]
        if let preparingPath {
          effects.append(.cancel(id: ChatRoomCancelID.pdfPreview(preparingPath)))
        }
        return .merge(effects)

      case let .bootstrapResponse(currentUserID, baseURL):
        state.currentUserID = currentUserID
        state.baseURL = baseURL
        return .none

      case let .localCacheLoaded(cached):
        // 서버 동기화가 먼저 도착했다면 덮지 않는다.
        guard !state.hasSyncedOnce, state.messages.isEmpty else { return .none }
        state.messages = sortedIdentified(cached)
        return .none

      case let .historyResponse(.success(messages)):
        state.isLoadingHistory = false
        state.hasSyncedOnce = true
        upsert(messages, into: &state.messages)
        return .none

      case let .historyResponse(.failure(error)):
        state.isLoadingHistory = false
        // 캐시 표시는 유지하고 alert만 띄운다.
        state.alert = AlertState {
          TextState("메시지를 불러오지 못했어요")
        } actions: {
          ButtonState(role: .cancel, action: .dismiss) {
            TextState("확인")
          }
        } message: {
          TextState(error.chatRoomUserFacingMessage)
        }
        return .none

      case let .socketEvent(.message(message)):
        upsert([message], into: &state.messages)
        let roomID = state.roomID
        let chatLocalStore = chatLocalStore
        // ChatList lastChat/정렬을 즉시 반영할 수 있도록 부모에 알림.
        return .merge(
          .run { _ in
            try? await chatLocalStore.upsertMessages([message], roomID)
          },
          .send(.delegate(.messageHandled))
        )

      case .socketEvent(.connected),
           .socketEvent(.disconnected):
        return .none

      case let .socketEvent(.authError(message)):
        state.alert = AlertState {
          TextState("연결할 수 없어요")
        } actions: {
          ButtonState(role: .cancel, action: .dismiss) {
            TextState("확인")
          }
        } message: {
          TextState(message)
        }
        return .none

      case let .socketEvent(.unknownError(message)):
        // 사용자에게는 노출하지 않고 디버그 용도로만 사용.
        // 추후 토스트 도입 시 대체.
        _ = message
        return .none

      case .sendTapped:
        guard state.canSend else { return .none }
        state.isSending = true

        let roomID = state.roomID
        let trimmed = state.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let content: String? = trimmed.isEmpty ? nil : trimmed
        let attachmentsToSend = state.attachments
        let chatClient = chatClient
        let chatLocalStore = chatLocalStore

        return .run { send in
          do {
            var filePaths: [String]? = nil
            if !attachmentsToSend.isEmpty {
              let uploaded = try await chatClient.uploadFiles(
                roomID,
                attachmentsToSend.map { $0.toUploadFile() }
              )
              filePaths = uploaded.files
            }

            let request = SendChatRequest(content: content, files: filePaths)
            let saved = try await chatClient.sendMessage(roomID, request)
            try? await chatLocalStore.upsertMessages([saved], roomID)
            await send(.sendResponse(.success(saved)))
          } catch {
            await send(.sendResponse(.failure(error)))
          }
        }
        .cancellable(id: ChatRoomCancelID.send(roomID), cancelInFlight: false)

      case let .sendResponse(.success(message)):
        state.isSending = false
        state.inputText = ""
        state.attachments.removeAll()
        upsert([message], into: &state.messages)
        // 본인이 보낸 메시지도 ChatList lastChat 갱신 트리거가 되어야 한다.
        return .send(.delegate(.messageHandled))

      case let .sendResponse(.failure(error)):
        state.isSending = false
        state.alert = AlertState {
          TextState("메시지를 보내지 못했어요")
        } actions: {
          ButtonState(role: .cancel, action: .dismiss) {
            TextState("확인")
          }
        } message: {
          TextState(error.chatRoomUserFacingMessage)
        }
        return .none

      case let .attachmentsAdded(items):
        let remaining = max(0, Self.maxAttachments - state.attachments.count)
        let accepted = Array(items.prefix(remaining))
        state.attachments.append(contentsOf: accepted)
        if accepted.count < items.count {
          state.alert = AlertState {
            TextState("첨부 한도를 초과했어요")
          } actions: {
            ButtonState(role: .cancel, action: .dismiss) {
              TextState("확인")
            }
          } message: {
            TextState("한 번에 최대 \(Self.maxAttachments)개의 파일만 첨부할 수 있어요.")
          }
        }
        return .none

      case let .attachmentRemoveTapped(id):
        state.attachments.removeAll { $0.id == id }
        return .none

      case let .attachmentLoadFailed(message):
        state.alert = AlertState {
          TextState("첨부를 불러오지 못했어요")
        } actions: {
          ButtonState(role: .cancel, action: .dismiss) {
            TextState("확인")
          }
        } message: {
          TextState(message)
        }
        return .none

      case let .pdfPreviewTapped(path):
        // 동시 다중 진행 방지: 이미 다른 path의 fetch가 돌고 있으면 무시.
        guard state.preparingPreviewPath == nil else { return .none }
        state.preparingPreviewPath = path
        let imageClient = imageClient
        return .run { send in
          do {
            let url = try await imageClient.localFileURL(path)
            await send(.pdfPreviewURLPrepared(.success(url), path: path))
          } catch is CancellationError {
            return
          } catch {
            await send(.pdfPreviewURLPrepared(.failure(error), path: path))
          }
        }
        .cancellable(id: ChatRoomCancelID.pdfPreview(path), cancelInFlight: true)

      case let .pdfPreviewURLPrepared(.success(url), _):
        state.preparingPreviewPath = nil
        state.previewingURL = url
        return .none

      case let .pdfPreviewURLPrepared(.failure(error), _):
        state.preparingPreviewPath = nil
        state.alert = AlertState {
          TextState("미리보기를 열지 못했어요")
        } actions: {
          ButtonState(role: .cancel, action: .dismiss) {
            TextState("확인")
          }
        } message: {
          TextState(error.chatRoomUserFacingMessage)
        }
        return .none

      case .pdfPreviewDismissed:
        state.previewingURL = nil
        return .none

      case .deleteRoomTapped:
        // SwiftUI Menu 의 destructive Button 이 환경에 따라 두 번 trigger 되는 케이스 방어.
        guard state.alert == nil else { return .none }
        state.alert = AlertState {
          TextState("이 채팅방을 삭제할까요?")
        } actions: {
          ButtonState(role: .cancel, action: .dismiss) {
            TextState("취소")
          }
          ButtonState(role: .destructive, action: .confirmDelete) {
            TextState("삭제")
          }
        } message: {
          TextState("이 기기에 저장된 대화 내역이 모두 삭제됩니다.")
        }
        return .none

      case .alert(.presented(.confirmDelete)):
        // TODO: 채팅방 삭제 로직 구현 필요. 서버 API 부재로 현재는 path pop / list refresh 만 수행.
        return .send(.delegate(.deleted))

      case .alert:
        return .none

      case .delegate:
        // delegate는 부모 피처에서 처리.
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
  }
}

// MARK: - Socket Loop

/// inner-group 종료 사유. socket stream과 sessionEvents stream을 동시에 await하며,
/// 어느 쪽이 먼저 신호를 보내는지에 따라 outer loop의 다음 동작(재연결/종료)을 결정한다.
private enum SocketLoopExit: Sendable {
  case streamEnded
  case tokenRefreshed
}

/// 토큰 갱신을 감지해 자동 재연결하는 socket 구독 루프.
///
/// 흐름:
///   while !cancelled:
///     1) snapshot()으로 최신 토큰을 읽고 socket connect → stream 획득
///     2) inner group에서 (a) stream 소비와 (b) sessionEvents 모니터링을 동시 실행
///     3) tokenRefreshed가 먼저 오면: disconnect 후 outer loop 재시작 → 새 토큰으로 재연결
///     4) stream이 자연 종료되면 outer loop 탈출 (서버 disconnect/auth error 등)
///
/// `send`/`disconnect` 흐름이 모두 Task.cancel에 응답하므로, ChatRoom .onDisappear 시
/// `ChatRoomCancelID.bootstrap` cancel만으로 정상 정리된다.
private func runSocketLoop(
  roomID: String,
  chatClient: ChatClient,
  chatSocketClient: ChatSocketClient,
  sessionClient: SessionClient,
  send: Send<ChatRoomFeature.Action>
) async {
  while !Task.isCancelled {
    let snapshot = await sessionClient.snapshot()

    let stream: AsyncStream<ChatSocketEvent>
    do {
      let connection = try await chatClient.socketConnection(roomID)
      stream = try await chatSocketClient.connect(
        roomID,
        connection.baseURL,
        connection.namespace,
        snapshot.configuration.seSACKey,
        snapshot.accessToken
      )
    } catch is CancellationError {
      return
    } catch {
      send(.socketEvent(.unknownError(error.localizedDescription)))
      return
    }

    let exit = await withTaskGroup(of: SocketLoopExit.self) { innerGroup -> SocketLoopExit in
      // (a) socket stream 소비
      innerGroup.addTask {
        for await event in stream {
          await send(.socketEvent(event))
        }
        return .streamEnded
      }
      // (b) 토큰 갱신 모니터링. invalidated는 root에서 처리하므로 무시.
      innerGroup.addTask {
        let events = await sessionClient.events()
        for await event in events {
          if case .tokenRefreshed = event {
            return .tokenRefreshed
          }
        }
        return .streamEnded
      }

      // 둘 중 먼저 끝나는 쪽이 종료 사유.
      let result = await innerGroup.next() ?? .streamEnded
      innerGroup.cancelAll()
      return result
    }

    switch exit {
    case .tokenRefreshed:
      // 기존 socket을 끊고 outer loop 다음 iteration에서 새 snapshot으로 재연결한다.
      await chatSocketClient.disconnect(roomID)
      // continue
    case .streamEnded:
      // 서버 disconnect / auth error / Task cancel 등 자연 종료. 루프 탈출.
      return
    }
  }
}

// MARK: - Helpers

/// `chat_id` 기반 dedup. 서버 history와 socket broadcast가 겹쳐도 동일 id로 upsert돼 중복되지 않는다.
/// 동일 `createdAt`(ms 미만 충돌)일 때는 `chat_id`를 secondary key로 사용해 정렬을 안정화한다.
private func upsert(
  _ incoming: [ChatMessage],
  into target: inout IdentifiedArrayOf<ChatMessage>
) {
  for message in incoming {
    target[id: message.chatID] = message
  }
  target.sort { lhs, rhs in
    if lhs.createdAt == rhs.createdAt { return lhs.chatID < rhs.chatID }
    return lhs.createdAt < rhs.createdAt
  }
}

private func sortedIdentified(_ messages: [ChatMessage]) -> IdentifiedArrayOf<ChatMessage> {
  var array = IdentifiedArrayOf<ChatMessage>()
  for message in messages {
    array[id: message.chatID] = message
  }
  array.sort { lhs, rhs in
    if lhs.createdAt == rhs.createdAt { return lhs.chatID < rhs.chatID }
    return lhs.createdAt < rhs.createdAt
  }
  return array
}

// MARK: - Error message

/// `ChatListFeature`의 메시지 톤과 동일하지만 도메인이 채팅방이라 분리한다.
extension Error {
  fileprivate var chatRoomUserFacingMessage: String {
    if let apiError = self as? APIError {
      switch apiError {
      case let .invalidBaseURL(message),
        let .invalidURL(message),
        let .transport(message),
        let .decoding(message):
        return message

      case .missingAccessToken, .missingRefreshToken:
        return "인증 정보가 없어 채팅을 사용할 수 없어요."

      case let .invalidSession(statusCode):
        return "세션이 유효하지 않습니다. 다시 로그인해 주세요. (\(statusCode))"

      case let .server(statusCode, message, _):
        if let message, !message.isEmpty {
          return message
        }
        return "서버 응답을 불러오지 못했어요. (\(statusCode))"
      }
    }

    return "채팅을 처리하지 못했어요. 잠시 후 다시 시도해 주세요."
  }
}

// MARK: - Task action

private extension ChatRoomFeature {
  func handleTaskAction(state: inout State) -> Effect<Action> {
    guard !state.isLoadingHistory else { return .none }
    state.isLoadingHistory = true

    let roomID = state.roomID
    let chatClient = chatClient
    let chatLocalStore = chatLocalStore
    let chatSocketClient = chatSocketClient
    let sessionClient = sessionClient

    // socket이 history보다 먼저 도착해도 dedup(upsert)이 안전. bootstrapResponse가 reducer 큐에서
    // 직렬 처리돼 socketEvent 시점에 currentUserID가 이미 채워진다.
    let bootstrapAndSocketEffect = Effect<Action>.run { send in
      let snapshot = await sessionClient.snapshot()
      await send(
        .bootstrapResponse(
          currentUserID: snapshot.currentUserID,
          baseURL: snapshot.configuration.baseURL
        )
      )

      if let cached = try? await chatLocalStore.loadMessages(roomID) {
        await send(.localCacheLoaded(cached))
      }

      await withTaskGroup(of: Void.self) { group in
        group.addTask {
          await runSocketLoop(
            roomID: roomID,
            chatClient: chatClient,
            chatSocketClient: chatSocketClient,
            sessionClient: sessionClient,
            send: send
          )
        }

        group.addTask {
          do {
            let nextCursor = try? await chatLocalStore.latestCreatedAtISO8601(roomID)
            let response = try await chatClient.listMessages(
              roomID,
              ChatHistoryQuery(next: nextCursor)
            )
            try? await chatLocalStore.upsertMessages(response.data, roomID)
            await send(.historyResponse(.success(response.data)))
          } catch is CancellationError {
            // 취소는 조용히 종료
          } catch {
            await send(.historyResponse(.failure(error)))
          }
        }
      }
    }
    .cancellable(id: ChatRoomCancelID.bootstrap(roomID), cancelInFlight: true)

    let currentChatRoomClient = currentChatRoomClient
    let trackCurrentRoomEffect = Effect<Action>.run { _ in
      await currentChatRoomClient.setCurrent(roomID)
    }

    // 방 진입 = 읽음 처리. idempotent.
    let clearUnreadEffect = Effect<Action>.run { _ in
      try? await chatLocalStore.clearUnread(roomID)
    }

    return .merge(bootstrapAndSocketEffect, trackCurrentRoomEffect, clearUnreadEffect)
  }
}
