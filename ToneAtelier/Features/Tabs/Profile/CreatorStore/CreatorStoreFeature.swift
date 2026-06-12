//
//  CreatorStoreFeature.swift
//  ToneAtelier
//
//  Created by Codex on 5/1/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct CreatorStoreFeature {
  @Dependency(\.userClient) var userClient
  @Dependency(\.filterClient) var filterClient
  @Dependency(\.toastClient) private var toastClient

  @ObservableState
  struct State: Equatable {
    @Presents var alert: AlertState<Action.Alert>?
    let userID: String
    let isOwn: Bool
    /// ProfileFeature가 미리 알고 있는 닉네임이 있으면 헤더에 즉시 표시한다.
    /// hero 로드 후에는 hero.nickname을 우선 사용.
    var headerName: String?
    var hero: CreatorStoreHero?
    var items: [CreatorStoreItem] = []
    var selectedTab: CreatorStoreFilterTab = .popular
    var isLoading = false
    var hasLoaded = false
    var errorMessage: String?
    /// 좋아요 토글 요청이 진행 중인 항목 id 집합. 동일 항목 중복 탭을 막고
    /// FeedListItemView의 `isLikeRequestInFlight` 표시에 사용한다.
    var likeRequestInFlightIDs: Set<CreatorStoreItem.ID> = []
    var deleteRequestInFlightIDs: Set<CreatorStoreItem.ID> = []

    init(
      userID: String,
      isOwn: Bool,
      headerName: String? = nil
    ) {
      self.userID = userID
      self.isOwn = isOwn
      self.headerName = headerName
    }

    /// 정렬 탭 적용 결과. selectedTab에 따라 클라이언트 사이드 정렬을 수행한다.
    /// - popular: likeCount 내림차순
    /// - recent: createdAt 내림차순. createdAt이 없는 항목은 뒤로 밀어낸다.
    var sortedItems: [CreatorStoreItem] {
      switch selectedTab {
      case .popular:
        return items.sorted { $0.likeCount > $1.likeCount }
      case .recent:
        return items.sorted { lhs, rhs in
          switch (lhs.createdAt, rhs.createdAt) {
          case let (l?, r?): return l > r
          case (_?, nil): return true
          case (nil, _?): return false
          case (nil, nil): return false
          }
        }
      }
    }
  }

  struct LoadedStore: Equatable, Sendable {
    var hero: CreatorStoreHero
    var items: [CreatorStoreItem]
  }

  enum Action: Sendable {
    case task
    case retryButtonTapped
    case loadResponse(Result<LoadedStore, Error>)
    case tabSelected(CreatorStoreFilterTab)
    case rowTapped(CreatorStoreItem.ID)
    case likeButtonTapped(CreatorStoreItem.ID)
    case likeResponse(id: CreatorStoreItem.ID, previousIsLiked: Bool, previousLikeCount: Int, Result<Bool, Error>)
    case createFilterButtonTapped
    case deleteButtonTapped(CreatorStoreItem.ID)
    case deleteResponse(id: CreatorStoreItem.ID, removedItem: CreatorStoreItem, Result<Void, Error>)
    case alert(PresentationAction<Alert>)
    /// 부모(path 부모 reducer) 가 detail 에서 일어난 좋아요 변동을 path 안 creatorStore element 에 동기화하기 위해 보낸다.
    case applyExternalLikeChange(id: String, isLiked: Bool, likeCount: Int?)
    case delegate(Delegate)

    enum Alert: Equatable, Sendable {
      case deleteConfirmed(CreatorStoreItem.ID)
    }

    enum Delegate: Equatable, Sendable {
      /// 작가 스토어 화면에서 좋아요 변동이 발생했음을 부모에게 전달.
      /// likeCount가 nil인 경우(서버 미보장)에는 토글 직후 클라가 추정한 값을 그대로 전달한다.
      case likeStatusChanged(CreatorStoreItem.ID, likeCount: Int?, isLiked: Bool)
      case makeFilterRequested
      /// 행 탭 시 부모가 path 에 detail element 를 push 한다.
      case detailRequested(CreatorStoreItem)
      case filterDeleted(CreatorStoreItem.ID)
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

      case let .loadResponse(.success(loaded)):
        state.isLoading = false
        state.hasLoaded = true
        state.errorMessage = nil
        state.hero = loaded.hero
        state.items = loaded.items
        return .none

      case let .loadResponse(.failure(error)):
        state.isLoading = false
        state.hasLoaded = true
        state.errorMessage = error.userFacingMessage
        return .none

      case let .tabSelected(tab):
        state.selectedTab = tab
        return .none

      case let .rowTapped(id):
        guard let item = state.items.first(where: { $0.id == id }) else { return .none }
        return .send(.delegate(.detailRequested(item)))

      case let .likeButtonTapped(id):
        guard !state.likeRequestInFlightIDs.contains(id),
              let item = state.items.first(where: { $0.id == id }) else {
          return .none
        }

        let previousIsLiked = item.isLiked
        let previousLikeCount = item.likeCount
        let targetStatus = !previousIsLiked

        // Optimistic update — 작가 스토어는 좋아요 해제 시에도 항목을 유지하고 isLiked만 갈아끼운다.
        state.likeRequestInFlightIDs.insert(id)
        state.items = state.items.map { current in
          current.id == id ? current.settingLike(targetStatus, likeCount: nil) : current
        }
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
        state.items = state.items.map { current in
          current.id == id ? current.settingLike(confirmedIsLiked, likeCount: nil) : current
        }
        // 서버 확정 결과로 한 번 더 부모에게 동기화.
        let confirmedCount = state.items.first(where: { $0.id == id })?.likeCount
        return .send(.delegate(.likeStatusChanged(id, likeCount: confirmedCount, isLiked: confirmedIsLiked)))

      case let .likeResponse(id, previousIsLiked, previousLikeCount, .failure):
        state.likeRequestInFlightIDs.remove(id)
        state.items = state.items.map { current in
          current.id == id ? current.settingLike(previousIsLiked, likeCount: previousLikeCount) : current
        }
        let toastClient = self.toastClient
        return .merge(
          .send(.delegate(.likeStatusChanged(id, likeCount: previousLikeCount, isLiked: previousIsLiked))),
          .run { _ in await toastClient.show("좋아요 처리에 실패했어요. 잠시 후 다시 시도해 주세요.") }
        )

      case .createFilterButtonTapped:
        return .send(.delegate(.makeFilterRequested))

      case let .deleteButtonTapped(id):
        guard state.isOwn,
              let item = state.items.first(where: { $0.id == id }),
              !state.deleteRequestInFlightIDs.contains(id) else {
          return .none
        }
        state.alert = AlertState {
          TextState("필터 삭제")
        } actions: {
          ButtonState(role: .destructive, action: .deleteConfirmed(id)) {
            TextState("삭제")
          }
          ButtonState(role: .cancel) {
            TextState("취소")
          }
        } message: {
          TextState("\(item.title) 을(를) 삭제하면 되돌릴 수 없어요.")
        }
        return .none

      case let .alert(.presented(.deleteConfirmed(id))):
        guard let removedItem = state.items.first(where: { $0.id == id }) else { return .none }
        state.deleteRequestInFlightIDs.insert(id)
        state.items.removeAll { $0.id == id }
        let filterClient = self.filterClient
        return .run { send in
          do {
            _ = try await filterClient.delete(id)
            await send(.deleteResponse(id: id, removedItem: removedItem, .success(())))
          } catch {
            await send(.deleteResponse(id: id, removedItem: removedItem, .failure(error)))
          }
        }
        .cancellable(id: CancelID.delete(id), cancelInFlight: true)

      case let .deleteResponse(id, _, .success):
        state.deleteRequestInFlightIDs.remove(id)
        return .send(.delegate(.filterDeleted(id)))

      case let .deleteResponse(id, removedItem, .failure(error)):
        state.deleteRequestInFlightIDs.remove(id)
        state.items.append(removedItem)
        state.alert = AlertState {
          TextState("삭제 실패")
        } actions: {
          ButtonState(role: .cancel) {
            TextState("확인")
          }
        } message: {
          TextState(error.userFacingMessage)
        }
        return .none

      case .alert:
        return .none

      case let .applyExternalLikeChange(id, isLiked, likeCount):
        state.items = state.items.map { item in
          item.id == id ? item.settingLike(isLiked, likeCount: likeCount) : item
        }
        return .none

      case .delegate:
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
  }

  private func load(into state: inout State) -> Effect<Action> {
    state.isLoading = true
    state.errorMessage = nil

    let userClient = self.userClient
    let filterClient = self.filterClient
    let userID = state.userID
    let presetHeaderName = state.headerName

    return .run { send in
      do {
        async let profileTask = userClient.fetchOtherProfile(userID)
        async let filtersTask = filterClient.userFilters(
          userID,
          UserFilterListQuery(next: nil, limit: 50, category: nil)
        )
        let profileResponse = try await profileTask
        let filtersResponse = try await filtersTask

        let items = CreatorStoreResponseParser.items(from: filtersResponse.data)
        let hero = CreatorStoreResponseParser.hero(
          from: profileResponse,
          fallbackName: presetHeaderName,
          filterCount: items.count
        )
        await send(.loadResponse(.success(LoadedStore(hero: hero, items: items))))
      } catch {
        await send(.loadResponse(.failure(error)))
      }
    }
    .cancellable(id: CancelID.load, cancelInFlight: true)
  }
}

// Reducer 외부에 두어 Sendable conformance가 main actor isolated되지 않도록 한다.
nonisolated private enum CancelID: Hashable, Sendable {
  case load
  case like(CreatorStoreItem.ID)
  case delete(CreatorStoreItem.ID)
}

// MARK: - Response Parser

/// 작가 스토어 화면 전용 응답 파서. spec UserInfoResponseDTO/FilterSummaryResponseDTO 기반 직접 매핑.
private enum CreatorStoreResponseParser {
  nonisolated static func hero(
    from response: UserInfoResponseDTO,
    fallbackName: String?,
    filterCount: Int
  ) -> CreatorStoreHero {
    let nickname = response.nick.trimmed.nilIfEmpty
      ?? fallbackName?.trimmed.nilIfEmpty
      ?? "작품"
    let name = response.name?.trimmed.nilIfEmpty
    let introduction = response.introduction?.trimmed.nilIfEmpty
    let profileImage = response.profileImage?.trimmed.nilIfEmpty

    return CreatorStoreHero(
      nickname: nickname,
      name: name,
      introduction: introduction,
      profileImageURL: profileImage,
      filterCount: filterCount
    )
  }

  nonisolated static func items(from items: [FilterSummaryResponseDTO]) -> [CreatorStoreItem] {
    items.map { item in
      CreatorStoreItem(
        id: item.filterID,
        title: item.title,
        author: item.creator.nick,
        authorUserID: item.creator.userID,
        category: item.category ?? "",
        description: item.description,
        likeCount: item.likeCount,
        imageURL: item.files.first?.trimmed.nilIfEmpty,
        // FilterSummaryResponseDTO에는 price 필드가 없다(상세 응답에만 존재).
        price: nil,
        createdAt: item.createdAt,
        isLiked: item.isLiked
      )
    }
  }
}

private extension String {
  nonisolated
  var nilIfEmpty: String? {
    isEmpty ? nil : self
  }
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
        return "인증 정보가 없어 작품을 불러올 수 없어요."

      case let .invalidSession(statusCode):
        return "세션이 유효하지 않습니다. 다시 로그인해 주세요. (\(statusCode))"

      case let .server(statusCode, message, _):
        if let message, !message.isEmpty {
          return message
        }
        return "서버 응답을 불러오지 못했어요. (\(statusCode))"
      }
    }

    return "작품을 불러오지 못했어요. 잠시 후 다시 시도해 주세요."
  }
}
