import ComposableArchitecture
import Foundation

struct ChatListSearchRecentStore: Sendable {
  var load: @Sendable () async -> [String]
  var save: @Sendable ([String]) async -> Void
}

extension ChatListSearchRecentStore: DependencyKey {
  static var liveValue: ChatListSearchRecentStore {
    let key = "chat.list.search.recents"
    return ChatListSearchRecentStore(
      load: {
        UserDefaults.standard.stringArray(forKey: key) ?? []
      },
      save: { keywords in
        UserDefaults.standard.set(keywords, forKey: key)
      }
    )
  }

  static let testValue = ChatListSearchRecentStore(
    load: { [] },
    save: { _ in }
  )
}

extension DependencyValues {
  var chatListSearchRecentStore: ChatListSearchRecentStore {
    get { self[ChatListSearchRecentStore.self] }
    set { self[ChatListSearchRecentStore.self] = newValue }
  }
}
