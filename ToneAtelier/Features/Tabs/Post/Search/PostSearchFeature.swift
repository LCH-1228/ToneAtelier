//
//  PostSearchFeature.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//
//  Pencil node: i6cSc (Post Search) + A503F (Post Search Empty)
//

import ComposableArchitecture
import Foundation

@Reducer
struct PostSearchFeature {
  @Dependency(\.postClient) private var postClient

  /// 추천 검색어 정적 5개. 디자인 텍스트 기반.
  static let suggestedKeywords: [String] = ["야경", "한강", "카페", "핫스팟", "별"]

  /// 검색 디바운스 타임. 사용자가 타이핑을 멈춘 뒤 0.3초 후 실제 호출.
  private static let debounceMillis: UInt64 = 300

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

    init() {}
  }

  enum Action: BindableAction, Sendable {
    case binding(BindingAction<State>)
    case task
    case queryChanged(String)
    case queryDebounceFinished(query: String)
    case searchResponse(query: String, Result<PostSummaryListResponseDTO, Error>)
    case resultRowTapped(postID: String)
    case suggestKeywordTapped(String)
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
        return .none

      case let .queryChanged(value):
        state.query = value
        return debounceQuery(state: &state)

      case let .queryDebounceFinished(query):
        // 디바운스 중에 query가 또 바뀌었거나 빈 문자열이면 무시.
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
        // 응답 도착 시점에 query가 바뀌었으면 그 결과는 폐기.
        guard query == state.query else { return .none }
        state.results = response.data
        state.phase = response.data.isEmpty ? .empty : .results
        state.errorMessage = nil
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

  /// query 변경에 대한 표준 디바운스 effect. 검색바 칩 탭 같은 즉시 호출 케이스는 immediate=true로.
  private func debounceQuery(state: inout State, immediate: Bool = false) -> Effect<Action> {
    let query = state.query
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !trimmed.isEmpty else {
      state.phase = .idle
      state.results = []
      // 입력이 비워졌으면 진행 중인 호출도 취소.
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
