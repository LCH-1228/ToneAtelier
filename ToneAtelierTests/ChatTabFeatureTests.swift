//
//  ChatTabFeatureTests.swift
//  ToneAtelierTests
//
//  Created by Codex on 4/29/26.
//

import ComposableArchitecture
import XCTest
@testable import ToneAtelier

@MainActor
final class ChatTabFeatureTests: XCTestCase {
  // MARK: - 1) 검색 버튼 → search push

  func testSearchButtonTappedAppendsSearch() async {
    let store = TestStore(initialState: ChatTabFeature.State()) {
      ChatTabFeature()
    }

    await store.send(.searchButtonTapped) {
      $0.path.append(.search(ChatSearchFeature.State()))
    }
  }

  // MARK: - 2) 리스트 행 탭 → chatRoom push (opponent를 currentUserID 기반으로 추출)

  func testListRoomTappedAppendsChatRoom() async {
    let me = ChatUserSummary(
      userID: "me",
      nick: "나",
      name: nil,
      introduction: nil,
      profileImage: nil,
      hashTags: nil
    )
    let other = ChatUserSummary(
      userID: "other",
      nick: "토니",
      name: nil,
      introduction: nil,
      profileImage: nil,
      hashTags: nil
    )
    let room = ChatRoom(
      roomID: "room-1",
      createdAt: "2026-04-29T08:00:00.000Z",
      updatedAt: "2026-04-29T09:00:00.000Z",
      participants: [me, other],
      lastChat: nil
    )

    var initialState = ChatTabFeature.State()
    initialState.list.currentUserID = "me"

    let store = TestStore(initialState: initialState) {
      ChatTabFeature()
    }

    await store.send(.list(.delegate(.roomTapped(room)))) {
      $0.path.append(
        .chatRoom(ChatRoomFeature.State(roomID: "room-1", opponent: other))
      )
    }
  }

  // MARK: - 3) 검색에서 채팅방 생성 → path reset 후 chatRoom push

  func testSearchRoomReadyResetsPathAndAppendsChatRoom() async {
    let opponent = ChatUserSummary(
      userID: "other",
      nick: "토니",
      name: nil,
      introduction: nil,
      profileImage: nil,
      hashTags: nil
    )
    let room = ChatRoom(
      roomID: "room-2",
      createdAt: "2026-04-29T08:00:00.000Z",
      updatedAt: "2026-04-29T08:30:00.000Z",
      participants: [opponent],
      lastChat: nil
    )

    var initialState = ChatTabFeature.State()
    initialState.path.append(.search(ChatSearchFeature.State()))

    let store = TestStore(initialState: initialState) {
      ChatTabFeature()
    }

    guard let searchID = store.state.path.ids.first else {
      XCTFail("search element가 path에 있어야 한다")
      return
    }

    await store.send(
      .path(.element(id: searchID, action: .search(.delegate(.roomReady(room, opponent: opponent)))))
    ) {
      $0.path.removeAll()
      $0.path.append(
        .chatRoom(ChatRoomFeature.State(roomID: "room-2", opponent: opponent))
      )
    }
  }

  // MARK: - 4) ChatRoom messageHandled → 부모가 list.refreshRequested 위임

  func testChatRoomMessageHandledTriggersListRefresh() async {
    let opponent = ChatUserSummary(
      userID: "other",
      nick: "토니",
      name: nil,
      introduction: nil,
      profileImage: nil,
      hashTags: nil
    )

    var initialState = ChatTabFeature.State()
    initialState.path.append(
      .chatRoom(ChatRoomFeature.State(roomID: "room-3", opponent: opponent))
    )

    let store = TestStore(initialState: initialState) {
      ChatTabFeature()
    } withDependencies: {
      // refreshRequested → chatClient.listRooms 호출 경로가 살아있어야 effect가 발사된다.
      // 회귀 핵심은 "부모가 자식 refreshRequested를 위임하는가" 이므로,
      // listRooms는 throw로 두어 후속 effect를 빠르게 종료시킨다.
      $0.chatClient.listRooms = {
        throw APIError.transport("test")
      }
      $0.chatLocalStore.upsertRooms = { _ in }
    }
    // 자식 effect의 alert/serverResponse 후속 검증은 본 테스트 범위 밖.
    // 라우팅 회귀의 핵심(refreshRequested 위임)만 검증한다.
    store.exhaustivity = .off

    guard let chatRoomID = store.state.path.ids.first else {
      XCTFail("chatRoom element가 path에 있어야 한다")
      return
    }

    await store.send(
      .path(.element(id: chatRoomID, action: .chatRoom(.delegate(.messageHandled))))
    )
    await store.receive(\.list.refreshRequested)
  }
}
