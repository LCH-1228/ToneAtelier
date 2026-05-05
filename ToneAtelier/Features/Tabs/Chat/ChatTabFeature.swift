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
  }

  enum Action: Sendable {
    case list(ChatListFeature.Action)
    case path(StackActionOf<Path>)
    case searchButtonTapped
  }

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

      case let .path(.element(_, .userProfile(.delegate(.messageRequested(room, opponent))))):
        // 새 채팅방 생성 직후 — userProfile element 를 pop 하고 chatRoom push.
        if !state.path.isEmpty {
          state.path.removeLast()
        }
        state.path.append(
          .chatRoom(
            ChatRoomFeature.State(roomID: room.roomID, opponent: opponent)
          )
        )
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

      case .list, .path:
        return .none
      }
    }
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
