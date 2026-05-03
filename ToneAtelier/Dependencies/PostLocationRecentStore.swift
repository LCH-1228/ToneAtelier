//
//  PostLocationRecentStore.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//

import ComposableArchitecture
import Foundation

/// 게시글 위치 선택 화면의 "최근 선택" 캐시.
/// UserDefaults에 JSON으로 직렬화하여 5개까지 보관한다.
struct PostLocationRecentStore: Sendable {
  var load: @Sendable () async -> [PostLocationRecent]
  var save: @Sendable ([PostLocationRecent]) async -> Void
}

/// UserDefaults key + 한도. 프로젝트 default actor isolation이 MainActor라 명시적으로 nonisolated 지정.
private nonisolated let postLocationRecentStorageKey = "ToneAtelier.PostLocationRecentStore.recents"
private nonisolated let postLocationRecentMaxCount = 5

extension PostLocationRecentStore: DependencyKey {
  static let liveValue: PostLocationRecentStore = PostLocationRecentStore(
    load: {
      guard let data = UserDefaults.standard.data(forKey: postLocationRecentStorageKey) else { return [] }
      do {
        return try JSONDecoder().decode([PostLocationRecent].self, from: data)
      } catch {
        return []
      }
    },
    save: { recents in
      let trimmed = Array(recents.prefix(postLocationRecentMaxCount))
      do {
        let data = try JSONEncoder().encode(trimmed)
        UserDefaults.standard.set(data, forKey: postLocationRecentStorageKey)
      } catch {
        // 직렬화 실패는 사용자에게 보여줄 것이 없어 silent. 다음 save에서 재시도.
      }
    }
  )

  static let testValue = PostLocationRecentStore(
    load: { [] },
    save: { _ in }
  )
}

extension DependencyValues {
  var postLocationRecentStore: PostLocationRecentStore {
    get { self[PostLocationRecentStore.self] }
    set { self[PostLocationRecentStore.self] = newValue }
  }
}
