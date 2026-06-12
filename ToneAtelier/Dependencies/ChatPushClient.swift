//
//  ChatPushClient.swift
//  ToneAtelier
//
//  Created by Codex on 5/2/26.
//

import ComposableArchitecture
import Foundation

/// 푸시 알림 도착(willPresent)/탭(didReceive) 신호와 cold-launch pending payload를 중앙화한다.
/// AppDelegate가 publisher로, ChatListFeature/MainTabFeature가 subscriber로 사용한다.
///
/// pending payload 는 UserDefaults 에 동기로 보관한다. terminate 상태에서 launchOptions 를
/// 통해 받은 roomID 가 actor 스케줄링 race 로 stash 누락되는 문제를 방지하기 위함.
struct ChatPushClient {
  /// cold-launch 시 launchOptions 에서 추출한 roomID 를 동기로 저장하는 UserDefaults 키.
  /// AppDelegate 가 sync 로 set 하고, 본 client 의 consumePending 이 UserDefaults 를 우선 읽는다.
  nonisolated static let pendingRoomDefaultsKey = "chatPush.pendingRoomID"

  /// 도착 시 호출. ChatList에 unread 증가/refresh 신호를 흘린다.
  var notifyReceived: @Sendable (_ roomID: String) async -> Void
  /// 사용자 탭 시 호출. MainTab에 deep-link 신호를 흘린다.
  var notifyTapped: @Sendable (_ roomID: String) async -> Void
  /// 앱이 종료된 상태에서 푸시 탭으로 시작될 때 launchOptions의 roomID를 보관.
  var stashPending: @Sendable (_ roomID: String) async -> Void
  /// 인증 부트스트랩 완료 후 1회 소비.
  var consumePending: @Sendable () async -> String?
  var receivedRoomIDs: @Sendable () -> AsyncStream<String>
  var tappedRoomIDs: @Sendable () -> AsyncStream<String>
}

extension ChatPushClient: DependencyKey {
  static let liveValue: ChatPushClient = {
    let center = LiveChatPushCenter.shared
    return ChatPushClient(
      notifyReceived: { id in await center.notifyReceived(id) },
      notifyTapped: { id in await center.notifyTapped(id) },
      stashPending: { id in
        // sync 즉시 저장 — actor 스케줄링 race 방지 (terminate cold launch 대응).
        UserDefaults.standard.set(id, forKey: ChatPushClient.pendingRoomDefaultsKey)
        await center.stashPending(id)
      },
      consumePending: {
        if let value = UserDefaults.standard.string(forKey: ChatPushClient.pendingRoomDefaultsKey) {
          UserDefaults.standard.removeObject(forKey: ChatPushClient.pendingRoomDefaultsKey)
          _ = await center.consumePending()
          return value
        }
        return await center.consumePending()
      },
      receivedRoomIDs: {
        AsyncStream { continuation in
          let task = Task {
            let stream = await center.receivedStream()
            for await id in stream {
              continuation.yield(id)
            }
            continuation.finish()
          }

          continuation.onTermination = { _ in
            task.cancel()
          }
        }
      },
      tappedRoomIDs: {
        AsyncStream { continuation in
          let task = Task {
            let stream = await center.tappedStream()
            for await id in stream {
              continuation.yield(id)
            }
            continuation.finish()
          }

          continuation.onTermination = { _ in
            task.cancel()
          }
        }
      }
    )
  }()

  static let testValue = ChatPushClient(
    notifyReceived: { _ in },
    notifyTapped: { _ in },
    stashPending: { _ in },
    consumePending: { nil },
    receivedRoomIDs: { AsyncStream { _ in } },
    tappedRoomIDs: { AsyncStream { _ in } }
  )
}

extension DependencyValues {
  var chatPushClient: ChatPushClient {
    get { self[ChatPushClient.self] }
    set { self[ChatPushClient.self] = newValue }
  }
}

actor LiveChatPushCenter {
  static let shared = LiveChatPushCenter()

  private var pendingRoomID: String?
  private var receivedContinuations: [UUID: AsyncStream<String>.Continuation] = [:]
  private var tappedContinuations: [UUID: AsyncStream<String>.Continuation] = [:]

  func notifyReceived(_ roomID: String) {
    for continuation in receivedContinuations.values {
      continuation.yield(roomID)
    }
  }

  func notifyTapped(_ roomID: String) {
    for continuation in tappedContinuations.values {
      continuation.yield(roomID)
    }
  }

  func stashPending(_ roomID: String) {
    pendingRoomID = roomID
  }

  func consumePending() -> String? {
    let value = pendingRoomID
    pendingRoomID = nil
    return value
  }

  func receivedStream() -> AsyncStream<String> {
    let id = UUID()
    let stream = AsyncStream.makeStream(of: String.self)
    receivedContinuations[id] = stream.continuation
    stream.continuation.onTermination = { _ in
      Task {
        await self.removeReceivedContinuation(id: id)
      }
    }
    return stream.stream
  }

  func tappedStream() -> AsyncStream<String> {
    let id = UUID()
    let stream = AsyncStream.makeStream(of: String.self)
    tappedContinuations[id] = stream.continuation
    stream.continuation.onTermination = { _ in
      Task {
        await self.removeTappedContinuation(id: id)
      }
    }
    return stream.stream
  }

  private func removeReceivedContinuation(id: UUID) {
    receivedContinuations.removeValue(forKey: id)
  }

  private func removeTappedContinuation(id: UUID) {
    tappedContinuations.removeValue(forKey: id)
  }
}
