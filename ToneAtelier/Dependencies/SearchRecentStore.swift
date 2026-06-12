import ComposableArchitecture
import Foundation

/// 검색 입력의 최근 키워드 저장소. UserDefaults 기반.
/// `key` 인자로 도메인을 분리한다 (예: post / chat.list / chat.search).
struct SearchRecentStore: Sendable {
  var load: @Sendable (_ key: String) async -> [String]
  var save: @Sendable (_ key: String, _ keywords: [String]) async -> Void
}

extension SearchRecentStore: DependencyKey {
  static let liveValue = SearchRecentStore(
    load: { key in
      UserDefaults.standard.stringArray(forKey: storageKey(for: key)) ?? []
    },
    save: { key, keywords in
      UserDefaults.standard.set(keywords, forKey: storageKey(for: key))
    }
  )

  static let testValue = SearchRecentStore(
    load: { _ in [] },
    save: { _, _ in }
  )

  nonisolated private static func storageKey(for key: String) -> String {
    "search.recents.\(key)"
  }
}

extension DependencyValues {
  var searchRecentStore: SearchRecentStore {
    get { self[SearchRecentStore.self] }
    set { self[SearchRecentStore.self] = newValue }
  }
}

enum SearchRecentKey {
  static let post = "post"
  static let chatList = "chat.list"
  static let chatSearch = "chat.search"
}
