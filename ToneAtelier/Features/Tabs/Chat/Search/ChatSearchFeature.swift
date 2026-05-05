//
//  ChatSearchFeature.swift
//  ToneAtelier
//
//  Created by LCH on 4/29/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct ChatSearchFeature {
  @ObservableState
  struct State: Equatable {
    var query: String = ""
    var results: [ChatUserSummary] = []
    var isLoading = false
    /// 채팅방 생성 중에 다중 탭/이중 호출을 차단한다.
    var isCreatingRoom = false
    /// 마지막 검색 응답이 빈 결과였는지(empty state 분기).
    var hasSearched = false
    /// SessionClient에서 적재한 baseURL (프로필 이미지 절대경로 조립용).
    var baseURL: URL?

    var recentSearches: [String] = []

    @Presents var alert: AlertState<Action.Alert>?
  }

  enum Action: BindableAction, Sendable {
    case binding(BindingAction<State>)
    case task
    case sessionLoaded(baseURL: URL)
    case recentsLoaded([String])
    case searchTriggered(query: String)
    case searchSubmitted
    case searchResponse(Result<UserSearchResponse, Error>)
    case recentSearchTapped(String)
    case recentClearAllTapped
    case profileTapped(ChatUserSummary)
    case userSelected(ChatUserSummary)
    case createRoomResponse(Result<ChatRoom, Error>, opponent: ChatUserSummary)
    case alert(PresentationAction<Alert>)
    case delegate(Delegate)

    enum Alert: Equatable, Sendable {
      case dismiss
    }

    enum Delegate: Equatable, Sendable {
      /// 채팅방이 준비되면 부모에서 채팅방 화면으로 라우팅한다.
      case roomReady(ChatRoom, opponent: ChatUserSummary)
      /// "프로필" 버튼 → 부모가 UserProfile 화면으로 push 한다.
      case profileRequested(ChatUserSummary)
    }
  }

  @Dependency(\.userClient) private var userClient
  @Dependency(\.chatClient) private var chatClient
  @Dependency(\.searchRecentStore) private var recentStore
  @Dependency(\.sessionClient) private var sessionClient
  @Dependency(\.continuousClock) private var clock

  var body: some Reducer<State, Action> {
    BindingReducer()

    Reduce { state, action in
      switch action {
      case .binding(\.query):
        let query = state.query.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
          state.results = []
          state.hasSearched = false
          state.isLoading = false
          // 입력이 비워지면 진행 중 검색 effect를 정리한다.
          return .cancel(id: ChatSearchCancelID.search)
        }

        state.isLoading = true
        let clock = clock
        return .run { send in
          // 디바운스: 입력이 멈추고 300ms 경과 시 검색.
          try await clock.sleep(for: .milliseconds(300))
          await send(.searchTriggered(query: query))
        }
        .cancellable(id: ChatSearchCancelID.search, cancelInFlight: true)

      case .binding:
        return .none

      case .task:
        let sessionClient = sessionClient
        let recentStore = recentStore
        return .run { send in
          let snapshot = await sessionClient.snapshot()
          await send(.sessionLoaded(baseURL: snapshot.configuration.baseURL))
          await send(.recentsLoaded(await recentStore.load(SearchRecentKey.chatSearch)))
        }

      case let .sessionLoaded(baseURL):
        state.baseURL = baseURL
        return .none

      case let .recentsLoaded(list):
        state.recentSearches = list
        return .none

      case let .searchTriggered(query):
        // 디바운스 통과 시점의 query가 현재 입력과 동일한지 한 번 더 검사
        // (사용자가 다시 비웠으면 호출하지 않는다).
        let currentTrimmed = state.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !currentTrimmed.isEmpty, currentTrimmed == query else {
          state.isLoading = false
          return .none
        }

        let userClient = userClient
        return .run { send in
          do {
            let response = try await userClient.searchUsers(query)
            await send(.searchResponse(.success(response)))
          } catch is CancellationError {
            return
          } catch {
            await send(.searchResponse(.failure(error)))
          }
        }
        .cancellable(id: ChatSearchCancelID.search, cancelInFlight: true)

      case .searchSubmitted:
        let trimmed = state.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .none }
        var list = state.recentSearches.filter { $0 != trimmed }
        list.insert(trimmed, at: 0)
        if list.count > 10 { list = Array(list.prefix(10)) }
        state.recentSearches = list
        let recentStore = recentStore
        return .run { _ in await recentStore.save(SearchRecentKey.chatSearch, list) }

      case let .searchResponse(.success(response)):
        state.isLoading = false
        state.hasSearched = true
        state.results = response.data
        return .none

      case let .searchResponse(.failure(error)):
        state.isLoading = false
        state.hasSearched = true
        state.alert = AlertState {
          TextState("사용자를 찾을 수 없어요")
        } actions: {
          ButtonState(role: .cancel, action: .dismiss) {
            TextState("확인")
          }
        } message: {
          TextState(error.chatSearchUserFacingMessage)
        }
        return .none

      case let .recentSearchTapped(keyword):
        state.query = keyword
        return .none

      case .recentClearAllTapped:
        state.recentSearches = []
        let recentStore = recentStore
        return .run { _ in await recentStore.save(SearchRecentKey.chatSearch, []) }

      case let .profileTapped(user):
        return .send(.delegate(.profileRequested(user)))

      case let .userSelected(user):
        guard !state.isCreatingRoom else { return .none }
        state.isCreatingRoom = true

        let chatClient = chatClient
        let request = CreateChatRoomRequest(opponentID: user.userID)

        return .run { send in
          do {
            let room = try await chatClient.createRoom(request)
            await send(.createRoomResponse(.success(room), opponent: user))
          } catch is CancellationError {
            return
          } catch {
            await send(.createRoomResponse(.failure(error), opponent: user))
          }
        }
        .cancellable(id: ChatSearchCancelID.createRoom, cancelInFlight: false)

      case let .createRoomResponse(.success(room), opponent):
        state.isCreatingRoom = false
        return .send(.delegate(.roomReady(room, opponent: opponent)))

      case let .createRoomResponse(.failure(error), _):
        state.isCreatingRoom = false
        state.alert = AlertState {
          TextState("채팅방을 만들지 못했어요")
        } actions: {
          ButtonState(role: .cancel, action: .dismiss) {
            TextState("확인")
          }
        } message: {
          TextState(error.chatSearchUserFacingMessage)
        }
        return .none

      case .alert:
        return .none

      case .delegate:
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
  }
}

// MARK: - Error message

/// `ChatListFeature`/`ChatRoomFeature`의 메시지 톤과 동일하지만 도메인이 검색이라 분리.
private extension Error {
  var chatSearchUserFacingMessage: String {
    if let apiError = self as? APIError {
      switch apiError {
      case let .invalidBaseURL(message),
        let .invalidURL(message),
        let .transport(message),
        let .decoding(message):
        return message

      case .missingAccessToken, .missingRefreshToken:
        return "인증 정보가 없어 검색을 사용할 수 없어요."

      case let .invalidSession(statusCode):
        return "세션이 유효하지 않습니다. 다시 로그인해 주세요. (\(statusCode))"

      case let .server(statusCode, message, _):
        if let message, !message.isEmpty {
          return message
        }
        return "서버 응답을 불러오지 못했어요. (\(statusCode))"
      }
    }

    return "잠시 후 다시 시도해 주세요."
  }
}
