//
//  PostSearchFeature.swift
//  ToneAtelier
//

import ComposableArchitecture
import Foundation

@Reducer
struct PostSearchFeature {
  @Dependency(\.postClient) private var postClient
  @Dependency(\.searchRecentStore) private var recentStore

  static let recentLimit = 8

  private static let debounceMillis: UInt64 = 800

  enum Phase: Equatable, Sendable {
    case idle
    case loading
    case results
    case empty
  }

  @ObservableState
  struct State: Equatable {
    var query: String = ""
    var phase: Phase = .idle
    var results: [PostSummaryResponseDTO] = []
    var errorMessage: String?
    var recents: [String] = []

    init() {}
  }

  enum Action: BindableAction, Sendable {
    case binding(BindingAction<State>)
    case task
    case recentsLoaded([String])
    case queryChanged(String)
    case queryDebounceFinished(query: String)
    case searchResponse(query: String, Result<PostSummaryListResponseDTO, Error>)
    case resultRowTapped(postID: String)
    case suggestKeywordTapped(String)
    case recentsClearTapped
    case emptyRetryTapped
    case closeTapped
    case delegate(Delegate)

    enum Delegate: Equatable, Sendable {
      case dismiss
      case postDetailRequested(postID: String)
    }
  }

  var body: some Reducer<State, Action> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .binding(\.query):
        return debounceQuery(state: &state)

      case .binding:
        return .none

      case .task:
        let recentStore = recentStore
        return .run { send in
          let recents = await recentStore.load(SearchRecentKey.post)
          await send(.recentsLoaded(recents))
        }
        .cancellable(id: "PostSearchFeature.recents", cancelInFlight: true)

      case let .recentsLoaded(recents):
        state.recents = recents
        return .none

      case let .queryChanged(value):
        state.query = value
        return debounceQuery(state: &state)

      case let .queryDebounceFinished(query):
        guard query == state.query else { return .none }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
          state.phase = .idle
          state.results = []
          return .none
        }

        state.phase = .loading
        state.errorMessage = nil

        let postClient = postClient
        return .run { send in
          await send(
            .searchResponse(
              query: query,
              Result {
                try await postClient.search(trimmed)
              }
            )
          )
        }
        .cancellable(id: "PostSearchFeature.search", cancelInFlight: true)

      case let .searchResponse(query, .success(response)):
        guard query == state.query else { return .none }
        state.results = response.data
        state.phase = response.data.isEmpty ? .empty : .results
        state.errorMessage = nil

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
          state.recents = Self.upsertRecent(trimmed, into: state.recents)
          let snapshot = state.recents
          let recentStore = recentStore
          return .run { _ in await recentStore.save(SearchRecentKey.post, snapshot) }
        }
        return .none

      case let .searchResponse(query, .failure(error)):
        guard query == state.query else { return .none }
        state.results = []
        state.phase = .empty
        state.errorMessage = Self.userFacingMessage(for: error)
        return .none

      case let .resultRowTapped(postID):
        return .send(.delegate(.postDetailRequested(postID: postID)))

      case let .suggestKeywordTapped(keyword):
        state.query = keyword
        return debounceQuery(state: &state, immediate: true)

      case .recentsClearTapped:
        state.recents = []
        let recentStore = recentStore
        return .run { _ in await recentStore.save(SearchRecentKey.post, []) }

      case .emptyRetryTapped:
        state.query = ""
        state.results = []
        state.phase = .idle
        state.errorMessage = nil
        return .none

      case .closeTapped:
        return .send(.delegate(.dismiss))

      case .delegate:
        return .none
      }
    }
  }

  private func debounceQuery(state: inout State, immediate: Bool = false) -> Effect<Action> {
    let query = state.query
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !trimmed.isEmpty else {
      state.phase = .idle
      state.results = []
      return .cancel(id: "PostSearchFeature.search")
    }

    if immediate {
      return .send(.queryDebounceFinished(query: query))
    }

    return .run { send in
      try? await Task.sleep(nanoseconds: Self.debounceMillis * 1_000_000)
      await send(.queryDebounceFinished(query: query))
    }
    .cancellable(id: "PostSearchFeature.queryDebounce", cancelInFlight: true)
  }

  private static func upsertRecent(_ keyword: String, into recents: [String]) -> [String] {
    var filtered = recents.filter { $0 != keyword }
    filtered.insert(keyword, at: 0)
    return Array(filtered.prefix(recentLimit))
  }

  private static func userFacingMessage(for error: Error) -> String {
    if let apiError = error as? APIError {
      switch apiError {
      case let .invalidBaseURL(message),
           let .invalidURL(message),
           let .transport(message),
           let .decoding(message):
        return message

      case .missingAccessToken, .missingRefreshToken:
        return "인증 정보가 없어 검색을 할 수 없어요."

      case let .invalidSession(statusCode):
        return "세션이 유효하지 않습니다. 다시 로그인해 주세요. (\(statusCode))"

      case let .server(statusCode, message, _):
        if let message, !message.isEmpty {
          return message
        }
        return "검색 결과를 불러오지 못했어요. (\(statusCode))"
      }
    }
    return "검색 결과를 불러오지 못했어요. 잠시 후 다시 시도해 주세요."
  }
}
