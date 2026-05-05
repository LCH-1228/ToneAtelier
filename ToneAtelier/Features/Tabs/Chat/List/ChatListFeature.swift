//
//  ChatListFeature.swift
//  ToneAtelier
//
//  Created by LCH on 4/29/26.
//

import ComposableArchitecture
import Foundation

enum ChatListFilter: String, Equatable, Sendable, CaseIterable {
  case all
  case unread

  var title: String {
    switch self {
    case .all: return "전체"
    case .unread: return "읽지 않음"
    }
  }
}

@Reducer
struct ChatListFeature {
  @ObservableState
  struct State: Equatable {
    /// 캐시 + 서버 동기화 결과. updatedAt 내림차순으로 정렬되어 있음.
    var rooms: [ChatRoom] = []
    /// roomID → 미읽음 카운트. SwiftData에 영구 저장된 값을 미러.
    var unreadCounts: [String: Int] = [:]
    var isLoading = false
    var hasLoadedOnce = false
    /// SessionClient에서 적재한 현재 사용자 ID (행 상대방 판별용).
    var currentUserID: String?
    /// SessionClient에서 적재한 baseURL (프로필 이미지 절대경로 조립용).
    var baseURL: URL?

    var query: String = ""
    var filter: ChatListFilter = .all
    var recentSearches: [String] = []

    @Presents var alert: AlertState<Action.Alert>?

    var displayedRooms: [ChatRoom] {
      let filtered: [ChatRoom]
      switch filter {
      case .all:
        filtered = rooms
      case .unread:
        filtered = rooms.filter { (unreadCounts[$0.roomID] ?? 0) > 0 }
      }

      let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { return filtered }
      let lower = trimmed.lowercased()
      return filtered.filter { room in
        let opponentNick = opponentNick(in: room).lowercased()
        if opponentNick.contains(lower) { return true }
        if let last = room.lastChat?.content, last.lowercased().contains(lower) {
          return true
        }
        return false
      }
    }

    private func opponentNick(in room: ChatRoom) -> String {
      if let currentUserID,
        let other = room.participants.first(where: { $0.userID != currentUserID }) {
        return other.nick
      }
      return room.participants.first?.nick ?? ""
    }
  }

  enum Action: BindableAction, Sendable {
    case binding(BindingAction<State>)
    case task
    case sessionLoaded(currentUserID: String?, baseURL: URL)
    case localCacheLoaded([ChatRoom])
    case unreadCountsLoaded([String: Int])
    case recentsLoaded([String])
    case serverResponse(Result<[ChatRoom], Error>)
    case refreshRequested
    case rowTapped(ChatRoom)
    case pushReceived(roomID: String)
    case filterSelected(ChatListFilter)
    case searchSubmitted
    case recentSearchTapped(String)
    case recentClearAllTapped
    case alert(PresentationAction<Alert>)
    case delegate(Delegate)

    enum Alert: Equatable, Sendable {}

    enum Delegate: Equatable, Sendable {
      /// 단계 4에서 부모(MainTab/ChatTabFeature)가 받아 ChatRoom navigation에 사용.
      case roomTapped(ChatRoom)
    }
  }

  @Dependency(\.chatClient) private var chatClient
  @Dependency(\.chatLocalStore) private var chatLocalStore
  @Dependency(\.chatPushClient) private var chatPushClient
  @Dependency(\.chatListSearchRecentStore) private var recentStore
  @Dependency(\.sessionClient) private var sessionClient

  var body: some Reducer<State, Action> {
    BindingReducer()

    Reduce { state, action in
      switch action {
      case .binding:
        return .none

      case .task:
        guard !state.isLoading else { return .none }
        state.isLoading = true

        let chatClient = chatClient
        let chatLocalStore = chatLocalStore
        let chatPushClient = chatPushClient
        let recentStore = recentStore
        let sessionClient = sessionClient

        let bootstrapEffect = Effect<Action>.run { send in
          // 1) 세션 메타 로드 (currentUserID, baseURL)
          let snapshot = await sessionClient.snapshot()
          await send(
            .sessionLoaded(
              currentUserID: snapshot.currentUserID,
              baseURL: snapshot.configuration.baseURL
            )
          )

          // 2) 캐시 즉시 표시
          if let cached = try? await chatLocalStore.loadRooms() {
            await send(.localCacheLoaded(cached))
          }
          if let unread = try? await chatLocalStore.loadUnreadCounts() {
            await send(.unreadCountsLoaded(unread))
          }
          await send(.recentsLoaded(await recentStore.load()))

          // 3) 서버 동기화
          do {
            let response = try await chatClient.listRooms()
            try? await chatLocalStore.upsertRooms(response.data)
            await send(.serverResponse(.success(response.data)))
            if let unread = try? await chatLocalStore.loadUnreadCounts() {
              await send(.unreadCountsLoaded(unread))
            }
          } catch {
            await send(.serverResponse(.failure(error)))
          }
        }
        .cancellable(id: "ChatListFeature.task", cancelInFlight: true)

        // 푸시 도착 신호 구독 — ChatList 살아있는 동안 lastChat/정렬 갱신.
        let pushSubscriptionEffect = Effect<Action>.run { send in
          for await roomID in chatPushClient.receivedRoomIDs() {
            await send(.pushReceived(roomID: roomID))
          }
        }
        .cancellable(id: "ChatListFeature.pushSubscription", cancelInFlight: true)

        return .merge(bootstrapEffect, pushSubscriptionEffect)

      case let .sessionLoaded(currentUserID, baseURL):
        state.currentUserID = currentUserID
        state.baseURL = baseURL
        return .none

      case let .localCacheLoaded(rooms):
        // 서버 응답이 이미 도착했거나 다른 경로로 rooms가 채워졌다면 덮어쓰지 않는다.
        // 서버 실패 → 캐시 늦게 도착 시퀀스에서 alert/표시 상태를 보존하기 위함.
        guard !state.hasLoadedOnce, state.rooms.isEmpty else { return .none }
        state.rooms = sortedByUpdatedAtDesc(rooms)
        return .none

      case let .unreadCountsLoaded(map):
        state.unreadCounts = map
        return .none

      case let .recentsLoaded(list):
        state.recentSearches = list
        return .none

      case let .serverResponse(.success(rooms)):
        state.isLoading = false
        state.hasLoadedOnce = true
        state.rooms = sortedByUpdatedAtDesc(rooms)
        return .none

      case let .serverResponse(.failure(error)):
        state.isLoading = false
        // 캐시 표시는 유지하고, 사용자에게는 알림만.
        state.alert = AlertState {
          TextState("채팅방을 불러오지 못했어요")
        } actions: {
          ButtonState(role: .cancel) {
            TextState("확인")
          }
        } message: {
          TextState(error.chatUserFacingMessage)
        }
        return .none

      case .refreshRequested:
        guard !state.isLoading else { return .none }
        state.isLoading = true

        let chatClient = chatClient
        let chatLocalStore = chatLocalStore

        return .run { send in
          do {
            let response = try await chatClient.listRooms()
            try? await chatLocalStore.upsertRooms(response.data)
            await send(.serverResponse(.success(response.data)))
            if let unread = try? await chatLocalStore.loadUnreadCounts() {
              await send(.unreadCountsLoaded(unread))
            }
          } catch {
            await send(.serverResponse(.failure(error)))
          }
        }
        .cancellable(id: "ChatListFeature.task", cancelInFlight: true)

      case let .rowTapped(room):
        return .send(.delegate(.roomTapped(room)))

      case let .pushReceived(roomID):
        // SwiftData에 unread +1 → refresh가 server lastChat 받아오고 unread 다시 로드
        let chatLocalStore = chatLocalStore
        return .merge(
          .run { _ in try? await chatLocalStore.incrementUnread(roomID) },
          .send(.refreshRequested)
        )

      case let .filterSelected(filter):
        state.filter = filter
        return .none

      case .searchSubmitted:
        let trimmed = state.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .none }
        var list = state.recentSearches.filter { $0 != trimmed }
        list.insert(trimmed, at: 0)
        if list.count > 10 { list = Array(list.prefix(10)) }
        state.recentSearches = list
        let recentStore = recentStore
        return .run { _ in await recentStore.save(list) }

      case let .recentSearchTapped(keyword):
        state.query = keyword
        return .none

      case .recentClearAllTapped:
        state.recentSearches = []
        let recentStore = recentStore
        return .run { _ in await recentStore.save([]) }

      case .alert:
        return .none

      case .delegate:
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
  }
}

// MARK: - Sorting

/// `updatedAt` 내림차순 정렬. ISO8601 문자열은 fractional seconds 자릿수가 일정해
/// lexicographic 비교가 시각순과 동치이므로 String 비교로 단순화한다.
private func sortedByUpdatedAtDesc(_ rooms: [ChatRoom]) -> [ChatRoom] {
  rooms.sorted { lhs, rhs in lhs.updatedAt > rhs.updatedAt }
}

// MARK: - Error message

/// FeedFeature/HomeFeature의 `Error.userFacingMessage` 패턴과 동일한 톤.
/// 채팅 도메인 한정 메시지는 본 확장에서 결정한다.
private extension Error {
  var chatUserFacingMessage: String {
    if let apiError = self as? APIError {
      switch apiError {
      case let .invalidBaseURL(message),
        let .invalidURL(message),
        let .transport(message),
        let .decoding(message):
        return message

      case .missingAccessToken, .missingRefreshToken:
        return "인증 정보가 없어 채팅방을 불러올 수 없어요."

      case let .invalidSession(statusCode):
        return "세션이 유효하지 않습니다. 다시 로그인해 주세요. (\(statusCode))"

      case let .server(statusCode, message, _):
        if let message, !message.isEmpty {
          return message
        }
        return "서버 응답을 불러오지 못했어요. (\(statusCode))"
      }
    }

    return "채팅방을 불러오지 못했어요. 잠시 후 다시 시도해 주세요."
  }
}
