import ComposableArchitecture
import Foundation

struct ChatSearchRecentStore: Sendable {
  var load: @Sendable () async -> [String]
  var save: @Sendable ([String]) async -> Void
}

extension ChatSearchRecentStore: DependencyKey {
  static var liveValue: ChatSearchRecentStore {
    let key = "chat.search.recents"
    return ChatSearchRecentStore(
      load: {
        UserDefaults.standard.stringArray(forKey: key) ?? []
      },
      save: { keywords in
        UserDefaults.standard.set(keywords, forKey: key)
      }
    )
  }

  static let testValue = ChatSearchRecentStore(
    load: { [] },
    save: { _ in }
  )
}

extension DependencyValues {
  var chatSearchRecentStore: ChatSearchRecentStore {
    get { self[ChatSearchRecentStore.self] }
    set { self[ChatSearchRecentStore.self] = newValue }
  }
}
