//
//  PostModels.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//

import Foundation

/// rawValue는 백엔드 전송용. 한글 표시값과 동일하게 두고, 응답 검증 후 불일치 시 정정.
enum PostCategory: String, CaseIterable, Sendable, Equatable {
  case food = "푸드"
  case portrait = "인물"
  case landscape = "풍경"
  case nightscape = "야경"
  case star = "별"

  var displayName: String { rawValue }

  /// 디자인 자산이 별도 카테고리 아이콘을 두지 않으므로 SF Symbol로 우선 매핑.
  var iconSystemName: String {
    switch self {
    case .food: return "fork.knife"
    case .portrait: return "person.crop.circle"
    case .landscape: return "photo.on.rectangle"
    case .nightscape: return "moon.stars"
    case .star: return "sparkles"
    }
  }

  static func from(_ raw: String) -> PostCategory? {
    PostCategory(rawValue: raw)
  }
}

/// 서버 정렬 키. 백엔드 스펙 미확정 상태에서는 rawValue 그대로 보낸다.
enum PostListOrder: String, CaseIterable, Sendable, Equatable {
  case createdAt
  case likes

  var apiValue: String { rawValue }

  var displayName: String {
    switch self {
    case .createdAt: return "최신순"
    case .likes: return "좋아요 많은 순"
    }
  }
}

/// 위치 권한 거부 시 listGeolocation 호출용 fallback 좌표.
enum PostLocationFallback {
  static let seoulCityHall = (latitude: 37.5663, longitude: 126.9779)
}
