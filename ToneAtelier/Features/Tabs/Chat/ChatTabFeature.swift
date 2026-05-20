//
//  ChatTabFeature.swift
//  ToneAtelier
//
//  Created by LCH on 4/29/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct ChatTabFeature {
  @Reducer(state: .equatable)
  enum Path {
    case chatRoom(ChatRoomFeature)
    case search(ChatSearchFeature)
    case userProfile(UserProfileFeature)
    case creatorStore(CreatorStoreFeature)
    case detail(HomeDetailFeature)
  }

  @ObservableState
  struct State: Equatable {
    var list = ChatListFeature.State()
    var path = StackState<Path.State>()
    @Presents var alert: AlertState<Action.Alert>?
  }

  enum Action: Sendable {
    case alert(PresentationAction<Alert>)
    case list(ChatListFeature.Action)
    case path(StackActionOf<Path>)
    case pathBecameEmpty
    case searchButtonTapped
    case createRoomResponse(Result<ChatRoom, Error>, opponent: ChatUserSummary, fromElementID: StackElementID?)

    enum Alert: Equatable, Sendable {}
  }

  @Dependency(\.chatClient) private var chatClient
  @Dependency(\.currentChatRoomClient) private var currentChatRoomClient

  var body: some Reducer<State, Action> {
    Scope(state: \.list, action: \.list) {
      ChatListFeature()
    }

    Reduce { state, action in
      switch action {
      case let .list(.delegate(.roomTapped(room))):
        let opponent = opponent(in: room, currentUserID: state.list.currentUserID)
        state.path.append(
          .chatRoom(
            ChatRoomFeature.State(roomID: room.roomID, opponent: opponent)
          )
        )
        return .none

      case let .path(.element(_, .search(.delegate(.roomReady(room, opponent))))):
        // 검색 화면을 모두 pop한 뒤 채팅방으로 push 한다.
        state.path.removeAll()
        state.path.append(
          .chatRoom(
            ChatRoomFeature.State(roomID: room.roomID, opponent: opponent)
          )
        )
        return .none

      case let .path(.element(_, .search(.delegate(.profileRequested(user))))):
        state.path.append(
          .userProfile(
            UserProfileFeature.State(
              userID: user.userID,
              initialNick: user.nick,
              initialIntroduction: user.introduction,
              initialProfileImage: user.profileImage
            )
          )
        )
        return .none

      case let .path(.element(elementID, .userProfile(.delegate(.messageRequested(userID, nick, introduction, profileImage))))):
        let opponent = ChatUserSummary(
          userID: userID,
          nick: nick,
          name: nil,
          introduction: introduction,
          profileImage: profileImage,
          hashTags: nil
        )
        let chatClient = chatClient
        return .run { send in
          do {
            let room = try await chatClient.createRoom(.init(opponentID: userID))
            await send(.createRoomResponse(.success(room), opponent: opponent, fromElementID: elementID))
          } catch is CancellationError {
            return
          } catch {
            await send(.createRoomResponse(.failure(error), opponent: opponent, fromElementID: elementID))
          }
        }

      case let .createRoomResponse(.success(room), opponent, fromElementID):
        if let fromElementID {
          state.path.pop(from: fromElementID)
        }
        state.path.append(
          .chatRoom(ChatRoomFeature.State(roomID: room.roomID, opponent: opponent))
        )
        return .none

      case let .createRoomResponse(.failure(error), _, _):
        state.alert = AlertState {
          TextState("채팅방을 만들지 못했어요")
        } actions: {
          ButtonState(role: .cancel) {
            TextState("확인")
          }
        } message: {
          TextState(error.chatRoomCreateFacingMessage)
        }
        return .none

      case .alert:
        return .none

      case let .path(.element(_, .userProfile(.delegate(.storeRequested(userID, headerName))))):
        state.path.append(
          .creatorStore(
            CreatorStoreFeature.State(userID: userID, isOwn: false, headerName: headerName)
          )
        )
        return .none

      case let .path(.element(_, .creatorStore(.delegate(.detailRequested(item))))):
        state.path.append(.detail(HomeDetailFeature.State(creatorStoreItem: item)))
        return .none

      case let .path(.element(_, .userProfile(.delegate(.featuredFilterRequested(filter))))):
        state.path.append(
          .detail(HomeDetailFeature.State(profileFeaturedFilter: filter))
        )
        return .none

      case .path(.element(_, .chatRoom(.delegate(.messageHandled)))):
        // ChatRoom에서 메시지 송수신이 처리됐다. 리스트의 lastChat/정렬을 즉시 갱신하기 위해
        // 자식의 refreshRequested를 위임한다(C3).
        return .send(.list(.refreshRequested))

      case let .path(.element(id, .chatRoom(.delegate(.deleted)))):
        state.path.pop(from: id)
        return .send(.list(.refreshRequested))

      case .searchButtonTapped:
        state.path.append(.search(ChatSearchFeature.State()))
        return .none

      case .pathBecameEmpty:
        // ChatRoom 의 .onDisappear 가 NavigationStack pop 후 발화되어 forEach 가 action 을 drop 하면
        // currentChatRoomClient.clearIfMatching 호출이 보장되지 않는다 — 부모가 root 복귀 시 무조건 clear.
        let currentChatRoomClient = currentChatRoomClient
        return .run { _ in await currentChatRoomClient.clear() }

      case .list, .path:
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
    .forEach(\.path, action: \.path)
  }

  // MARK: - Helpers

  /// 현재 사용자 ID 기준으로 상대방을 찾는다. 없으면 첫 참가자.
  private func opponent(
    in room: ChatRoom,
    currentUserID: String?
  ) -> ChatUserSummary? {
    if let currentUserID,
      let other = room.participants.first(where: { $0.userID != currentUserID })
    {
      return other
    }
    return room.participants.first
  }
}

private extension Error {
  var chatRoomCreateFacingMessage: String {
    if let apiError = self as? APIError {
      switch apiError {
      case let .invalidBaseURL(message),
           let .invalidURL(message),
           let .transport(message),
           let .decoding(message):
        return message
      case .missingAccessToken, .missingRefreshToken:
        return "인증 정보가 없어 채팅방을 만들 수 없어요."
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

extension ChatTabFeature.State {
  /// 푸시 탭 또는 cold-launch 시 외부에서 호출하는 deep-link 헬퍼.
  /// 이미 path 최상단이 같은 방이면 no-op (재진입 회피).
  /// opponent 정보는 푸시 payload에 없으므로 nil 진입.
  /// `ChatRoomFeature.State.displayOpponent`가 messages.first?.sender로 fallback 처리한다.
  mutating func deepLink(roomID: String, opponent: ChatUserSummary? = nil) {
    if let last = path.last, case let .chatRoom(roomState) = last,
       roomState.roomID == roomID {
      return
    }
    path.removeAll()
    path.append(.chatRoom(ChatRoomFeature.State(roomID: roomID, opponent: opponent)))
  }
}
