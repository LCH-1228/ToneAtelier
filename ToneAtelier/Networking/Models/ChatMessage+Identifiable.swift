//
//  ChatMessage+Identifiable.swift
//  ToneAtelier
//
//  Created by LCH on 4/29/26.
//

import Foundation

/// `IdentifiedArrayOf<ChatMessage>`/`ForEach`에서 사용하기 위한 Identifiable 부착.
/// `ChatModels.swift`의 모델 자체에 부착하지 않고 단계 3 도입 시점에 분리해 보관한다.
/// `nonisolated` 표기는 빌드 설정 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` 환경에서
/// Identifiable.id 접근이 임의 컨텍스트에서 안전하게 호출되도록 한다.
extension ChatMessage: Identifiable {
  nonisolated public var id: String { chatID }
}
