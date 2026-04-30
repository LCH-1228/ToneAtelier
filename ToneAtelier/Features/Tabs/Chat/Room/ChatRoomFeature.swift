//
//  ChatRoomFeature.swift
//  ToneAtelier
//
//  Created by LCH on 4/29/26.
//

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
  /// 이미지면 즉시 표시용 데이터(원본과 동일 가능). PDF면 nil.
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
struct ChatRoomFeature {
  /// 첨부 최대 개수. 명세 기준값.
  static let maxAttachments = 5
  /// 단일 첨부 최대 크기(바이트). 5MB.
  static let maxAttachmentBytes = 5 * 1024 * 1024

  @ObservableState
  struct State: Equatable {
    let roomID: String
    /// 부모(단계 4)에서 주입. 헤더 표시용. 없으면 history sender로 대체.
    let opponent: ChatUserSummary?

    var currentUserID: String?
    var baseURL: URL?

    var messages: IdentifiedArrayOf<ChatMessage> = []
    var inputText: String = ""
    var attachments: [LocalAttachment] = []

    var isLoadingHistory = false
    var isSending = false
    var hasSyncedOnce = false

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

    /// 헤더/메시지 셀에서 표시할 상대방 후보. 단계 4에서 opponent가 주입되지 않을 때
    /// 메시지 senders에서 currentUserID와 다른 첫 sender를 사용한다.
    var displayOpponent: ChatUserSummary? {
      if let opponent { return opponent }
      guard let currentUserID else { return messages.first?.sender }
      return messages.first(where: { $0.sender.user_id != currentUserID })?.sender
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
    case alert(PresentationAction<Alert>)

    enum Alert: Equatable, Sendable {
      case dismiss
    }
  }

  @Dependency(\.chatClient) private var chatClient
  @Dependency(\.chatLocalStore) private var chatLocalStore
  @Dependency(\.chatSocketClient) private var chatSocketClient
  @Dependency(\.sessionClient) private var sessionClient

  var body: some Reducer<State, Action> {
    BindingReducer()

    Reduce { state, action in
      switch action {
      case .binding:
        return .none

      case .task:
        guard !state.isLoadingHistory else { return .none }
        state.isLoadingHistory = true

        let roomID = state.roomID
        let chatClient = chatClient
        let chatLocalStore = chatLocalStore
        let chatSocketClient = chatSocketClient
        let sessionClient = sessionClient

        // bootstrap(세션 → 캐시 → history)을 먼저 끝낸 뒤 socket을 연결한다.
        // 이렇게 해야 socket broadcast가 도착했을 때 `state.currentUserID`가 nil이 아닌 상태로
        // 본인 메시지(isMine) 판정이 올바르게 동작한다(C1: socket race 방지).
        let bootstrapAndSocketEffect = Effect<Action>.run { send in
          // 1) 세션 메타 로드
          let snapshot = await sessionClient.snapshot()
          await send(
            .bootstrapResponse(
              currentUserID: snapshot.currentUserID,
              baseURL: snapshot.configuration.baseURL
            )
          )

          // 2) 로컬 캐시 즉시 표시 (서버 응답이 먼저 오면 무시됨)
          if let cached = try? await chatLocalStore.loadMessages(roomID) {
            await send(.localCacheLoaded(cached))
          }

          // 3) 서버 동기화 (캐시의 마지막 createdAt을 next로 전달)
          do {
            let nextCursor = try? await chatLocalStore.latestCreatedAtISO8601(roomID)
            let response = try await chatClient.listMessages(
              roomID,
              ChatHistoryQuery(next: nextCursor)
            )
            try? await chatLocalStore.upsertMessages(response.data, roomID)
            await send(.historyResponse(.success(response.data)))
          } catch {
            await send(.historyResponse(.failure(error)))
          }

          // 4) bootstrap 완료 후 socket 연결.
          //    의존성 조회는 main-actor 격리이므로 호출부에서 미리 수행한 뒤
          //    actor LiveChatSocketCenter에는 값으로 전달한다.
          do {
            let url = try await chatClient.socketURL(roomID)
            let stream = try await chatSocketClient.connect(
              roomID,
              url,
              snapshot.configuration.seSACKey,
              snapshot.accessToken
            )
            for await event in stream {
              await send(.socketEvent(event))
            }
          } catch {
            await send(.socketEvent(.unknownError(error.localizedDescription)))
          }
        }
        .cancellable(id: ChatRoomCancelID.bootstrap(roomID), cancelInFlight: true)

        return bootstrapAndSocketEffect

      case .onDisappear:
        let roomID = state.roomID
        let chatSocketClient = chatSocketClient
        return .merge(
          .cancel(id: ChatRoomCancelID.bootstrap(roomID)),
          .cancel(id: ChatRoomCancelID.send(roomID)),
          .run { _ in
            await chatSocketClient.disconnect(roomID)
          }
        )

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
        return .run { _ in
          try? await chatLocalStore.upsertMessages([message], roomID)
        }

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
        return .none

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

      case .alert:
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
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
    target[id: message.chat_id] = message
  }
  target.sort { lhs, rhs in
    if lhs.createdAt == rhs.createdAt { return lhs.chat_id < rhs.chat_id }
    return lhs.createdAt < rhs.createdAt
  }
}

private func sortedIdentified(_ messages: [ChatMessage]) -> IdentifiedArrayOf<ChatMessage> {
  var array = IdentifiedArrayOf<ChatMessage>()
  for message in messages {
    array[id: message.chat_id] = message
  }
  array.sort { lhs, rhs in
    if lhs.createdAt == rhs.createdAt { return lhs.chat_id < rhs.chat_id }
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
