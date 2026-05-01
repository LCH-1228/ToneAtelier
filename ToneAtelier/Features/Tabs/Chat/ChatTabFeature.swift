//
//  ChatTabFeature.swift
//  ToneAtelier
//
//  Created by LCH on 4/29/26.
//

import ComposableArchitecture
import Foundation

/// 채팅 탭 컨테이너. ChatList를 루트로, NavigationStack 경로에
/// ChatRoom / ChatSearch를 push 한다.
///
/// 라우팅 규약:
/// - List 행 탭 → ChatRoom push
/// - 우상단 + 버튼 → ChatSearch push
/// - Search에서 채팅방 생성 → 검색을 path에서 제거하고 ChatRoom push
@Reducer
struct ChatTabFeature {
  @Reducer(state: .equatable)
  enum Path {
    case chatRoom(ChatRoomFeature)
    case search(ChatSearchFeature)
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
            ChatRoomFeature.State(roomID: room.room_id, opponent: opponent)
          )
        )
        return .none

      case let .path(.element(_, .search(.delegate(.roomReady(room, opponent))))):
        // 검색 화면을 모두 pop한 뒤 채팅방으로 push 한다.
        // (1) 사용자가 뒤로가기 시 ChatRoom → List로 직행해 자연스럽고,
        // (2) ChatSearch가 메모리에서 즉시 해제돼 검색 결과/이미지 자원이 정리된다.
        // 가정: 검색은 path root(ChatList 위)에서만 진입함.
        // 따라서 path 전체를 reset해도 의도된 ChatRoom만 남는다.
        // 향후 ChatRoom 안에서 검색을 push하는 동선이 추가되면, search element만 좁게 pop하도록 수정 필요.
        state.path.removeAll()
        state.path.append(
          .chatRoom(
            ChatRoomFeature.State(roomID: room.room_id, opponent: opponent)
          )
        )
        return .none

      case .path(.element(_, .chatRoom(.delegate(.messageHandled)))):
        // ChatRoom에서 메시지 송수신이 처리됐다. 리스트의 lastChat/정렬을 즉시 갱신하기 위해
        // 자식의 refreshRequested를 위임한다(C3).
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
      let other = room.participants.first(where: { $0.user_id != currentUserID })
    {
      return other
    }
    return room.participants.first
  }
}
