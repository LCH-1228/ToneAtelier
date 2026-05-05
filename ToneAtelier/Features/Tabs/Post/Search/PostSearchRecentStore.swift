//
//  PostSearchRecentStore.swift
//  ToneAtelier
//

import ComposableArchitecture
import Foundation

struct PostSearchRecentStore: Sendable {
  var load: @Sendable () async -> [String]
  var save: @Sendable ([String]) async -> Void
}

extension PostSearchRecentStore: DependencyKey {
  static var liveValue: PostSearchRecentStore {
    let key = "post.search.recents"
    return PostSearchRecentStore(
      load: {
        UserDefaults.standard.stringArray(forKey: key) ?? []
      },
      save: { keywords in
        UserDefaults.standard.set(keywords, forKey: key)
      }
    )
  }

  static let testValue = PostSearchRecentStore(
    load: { [] },
    save: { _ in }
  )
}

extension DependencyValues {
  var postSearchRecentStore: PostSearchRecentStore {
    get { self[PostSearchRecentStore.self] }
    set { self[PostSearchRecentStore.self] = newValue }
  }
}
