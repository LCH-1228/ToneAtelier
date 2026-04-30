//
//  ChatRoomCancelID.swift
//  ToneAtelier
//
//  Created by LCH on 4/29/26.
//

import Foundation

/// `@Reducer` 매크로가 같은 파일 내 중첩/형제 정의들을 main-actor isolated로 추론하는 이슈를 회피하기 위해
/// 별도 파일로 분리한다. 이렇게 하면 nonisolated 컨텍스트로 해석되어
/// `Effect.cancellable(id:)` / `Effect.cancel(id:)`가 요구하는 `Hashable & Sendable` 제약을 만족한다.
nonisolated enum ChatRoomCancelID: Hashable, Sendable {
  /// bootstrap(세션/캐시/history) + socket 구독을 하나의 effect로 묶어 순차 보장.
  case bootstrap(String)
  /// `sendTapped`로 시작되는 업로드/전송 effect. onDisappear 시 일괄 취소.
  case send(String)
}
