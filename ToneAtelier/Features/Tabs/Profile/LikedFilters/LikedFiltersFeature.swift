//
//  LikedFiltersFeature.swift
//  ToneAtelier
//
//  Created by Codex on 5/1/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct LikedFiltersFeature {
  @Dependency(\.filterClient) var filterClient
  @Dependency(\.toastClient) private var toastClient

  @ObservableState
  struct State: Equatable {
    var items: [LikedFilter] = []
    var isLoading = false
    var hasLoaded = false
    var errorMessage: String?
    var detail: HomeDetailFeature.State?
    /// 좋아요 토글 요청이 진행 중인 항목 id 집합. 동일 항목 중복 탭을 막고
    /// FeedListItemView의 `isLikeRequestInFlight` 표시에 사용한다.
    var likeRequestInFlightIDs: Set<LikedFilter.ID> = []
  }

  enum Action: Sendable {
    case task
    case retryButtonTapped
    case itemsResponse(Result<[LikedFilter], Error>)
    case rowTapped(LikedFilter.ID)
    case likeButtonTapped(LikedFilter.ID)
    case likeResponse(id: LikedFilter.ID, previousIsLiked: Bool, previousLikeCount: Int, Result<Bool, Error>)
    case detail(HomeDetailFeature.Action)
    case detailDismissed
    case delegate(Delegate)

    enum Delegate: Equatable, Sendable {
      /// 좋아하는 필터 화면에서 좋아요 변동이 발생했음을 부모(ProfileFeature)에 알린다.
      /// likeCount가 nil인 경우(서버 미보장)에는 토글 직후 클라가 추정한 값을 그대로 전달한다.
      case likeStatusChanged(LikedFilter.ID, likeCount: Int?, isLiked: Bool)
    }
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .task:
        guard !state.hasLoaded else { return .none }
        return load(into: &state)

      case .retryButtonTapped:
        return load(into: &state)

      case let .itemsResponse(.success(items)):
        state.isLoading = false
        state.hasLoaded = true
        state.errorMessage = nil
        state.items = items
        return .none

      case let .itemsResponse(.failure(error)):
        state.isLoading = false
        state.hasLoaded = true
        state.errorMessage = error.userFacingMessage
        return .none

      case let .rowTapped(id):
        guard let filter = state.items.first(where: { $0.id == id }) else { return .none }
        state.detail = HomeDetailFeature.State(likedFilter: filter)
        return .none

      case let .likeButtonTapped(id):
        // 진행 중이거나 항목이 사라진 경우 무시.
        guard !state.likeRequestInFlightIDs.contains(id),
              let item = state.items.first(where: { $0.id == id }) else {
          return .none
        }

        let previousIsLiked = item.isLiked
        let previousLikeCount = item.likeCount
        let targetStatus = !previousIsLiked

        // 1) Optimistic update — UI 즉시 반영.
        state.likeRequestInFlightIDs.insert(id)
        state.items = state.items.map { current in
          current.id == id ? current.settingLike(targetStatus, likeCount: nil) : current
        }

        // 2) 부모 미리보기도 동시 동기화(롤백 시 likeResponse 실패 분기에서 재yield).
        let optimisticCount = state.items.first(where: { $0.id == id })?.likeCount ?? previousLikeCount
        let filterClient = self.filterClient
        return .merge(
          .send(.delegate(.likeStatusChanged(id, likeCount: optimisticCount, isLiked: targetStatus))),
          .run { send in
            await send(
              .likeResponse(
                id: id,
                previousIsLiked: previousIsLiked,
                previousLikeCount: previousLikeCount,
                Result { try await filterClient.setLike(id, targetStatus).likeStatus }
              )
            )
          }
          .cancellable(id: CancelID.like(id), cancelInFlight: true)
        )

      case let .likeResponse(id, _, _, .success(confirmedIsLiked)):
        state.likeRequestInFlightIDs.remove(id)

        if confirmedIsLiked {
          // 정상 토글 결과가 true 그대로 — items 상태는 optimistic update와 동일하므로 유지.
          // 다만 likeCount는 서버 응답이 없으므로 그대로 두고, 부모에게 한 번 더 동기화 신호.
          let currentCount = state.items.first(where: { $0.id == id })?.likeCount
          return .send(.delegate(.likeStatusChanged(id, likeCount: currentCount, isLiked: true)))
        } else {
          // 좋아요 해제가 확정 — "좋아한 목록"에서 제거.
          state.items.removeAll { $0.id == id }
          return .send(.delegate(.likeStatusChanged(id, likeCount: nil, isLiked: false)))
        }

      case let .likeResponse(id, previousIsLiked, previousLikeCount, .failure):
        state.likeRequestInFlightIDs.remove(id)
        // Optimistic update 롤백.
        state.items = state.items.map { current in
          current.id == id ? current.settingLike(previousIsLiked, likeCount: previousLikeCount) : current
        }
        let toastClient = self.toastClient
        // 부모 미리보기도 롤백된 값으로 재동기화 + 실패 Toast.
        return .merge(
          .send(.delegate(.likeStatusChanged(id, likeCount: previousLikeCount, isLiked: previousIsLiked))),
          .run { _ in await toastClient.show("좋아요 처리에 실패했어요. 잠시 후 다시 시도해 주세요.") }
        )

      case let .detail(.delegate(.likeStatusChanged(id, isLiked, likeCount))):
        state.items = state.items.map { item in
          item.id == id ? item.settingLike(isLiked, likeCount: likeCount) : item
        }
        // 부모(ProfileFeature)가 마이 화면 미리보기를 동기화할 수 있도록 후속 yield.
        return .send(.delegate(.likeStatusChanged(id, likeCount: likeCount, isLiked: isLiked)))

      case .detail:
        return .none

      case .detailDismissed:
        state.detail = nil
        return .none

      case .delegate:
        return .none
      }
    }
    .ifLet(\.detail, action: \.detail) {
      HomeDetailFeature()
    }
  }

  private func load(into state: inout State) -> Effect<Action> {
    state.isLoading = true
    state.errorMessage = nil

    let filterClient = self.filterClient

    return .run { send in
      do {
        let response = try await filterClient.likedFilters(
          UserFilterListQuery(next: nil, limit: 50, category: nil)
        )
        let items = ProfileResponseParser.likedFilters(from: response.data)
        await send(.itemsResponse(.success(items)))
      } catch {
        await send(.itemsResponse(.failure(error)))
      }
    }
    .cancellable(id: CancelID.load, cancelInFlight: true)
  }
}

// Reducer 외부에 두어 Sendable conformance가 main actor isolated되지 않도록 한다.
nonisolated private enum CancelID: Hashable, Sendable {
  case load
  case like(LikedFilter.ID)
}

// MARK: - Error Mapping

private extension Error {
  var userFacingMessage: String {
    if let apiError = self as? APIError {
      switch apiError {
      case let .invalidBaseURL(message),
           let .invalidURL(message),
           let .transport(message),
           let .decoding(message):
        return message

      case .missingAccessToken, .missingRefreshToken:
        return "인증 정보가 없어 좋아하는 필터를 불러올 수 없어요."

      case let .invalidSession(statusCode):
        return "세션이 유효하지 않습니다. 다시 로그인해 주세요. (\(statusCode))"

      case let .server(statusCode, message, _):
        if let message, !message.isEmpty {
          return message
        }
        return "서버 응답을 불러오지 못했어요. (\(statusCode))"
      }
    }

    return "좋아하는 필터를 불러오지 못했어요. 잠시 후 다시 시도해 주세요."
  }
}
