//
//  CurrentChatRoomClient.swift
//  ToneAtelier
//
//  Created by Codex on 5/2/26.
//

import ComposableArchitecture
import Foundation

/// 현재 사용자가 표시 중인 ChatRoom의 roomID를 추적한다.
/// 푸시 도착(willPresent) 시 활성 방 푸시 표시 억제 분기에 사용한다.
struct CurrentChatRoomClient {
  var setCurrent: @Sendable (_ roomID: String) async -> Void
  /// navigation push 시 새 ChatRoom의 .task가 이전 ChatRoom의 .onDisappear보다 먼저 실행돼도
  /// 새 값을 잃지 않도록 자기 roomID와 일치할 때만 clear 한다.
  var clearIfMatching: @Sendable (_ roomID: String) async -> Void
  var currentRoomID: @Sendable () async -> String?
}

extension CurrentChatRoomClient: DependencyKey {
  static let liveValue: CurrentChatRoomClient = {
    let center = LiveCurrentChatRoomCenter.shared
    return CurrentChatRoomClient(
      setCurrent: { id in await center.setCurrent(id) },
      clearIfMatching: { id in await center.clearIfMatching(id) },
      currentRoomID: { await center.current() }
    )
  }()

  static let testValue = CurrentChatRoomClient(
    setCurrent: { _ in },
    clearIfMatching: { _ in },
    currentRoomID: { nil }
  )
}

extension DependencyValues {
  var currentChatRoomClient: CurrentChatRoomClient {
    get { self[CurrentChatRoomClient.self] }
    set { self[CurrentChatRoomClient.self] = newValue }
  }
}

actor LiveCurrentChatRoomCenter {
  static let shared = LiveCurrentChatRoomCenter()

  private var roomID: String?

  func setCurrent(_ id: String) {
    roomID = id
  }

  func clearIfMatching(_ id: String) {
    if roomID == id {
      roomID = nil
    }
  }

  func current() -> String? {
    roomID
  }
}
