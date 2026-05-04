//
//  PostFeature.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//

// swiftlint:disable file_length
// 메인 리스트 + 위치 권한 + 페이지네이션 + 좋아요가 한 reducer 단위. 외부 분리 의미 없음.

import ComposableArchitecture
import CoreLocation
import Foundation

@Reducer
struct PostFeature {
  @Dependency(\.postClient) private var postClient
  @Dependency(\.sessionClient) private var sessionClient
  @Dependency(\.locationClient) private var locationClient

  @ObservableState
  struct State: Equatable {
    var posts: [PostSummaryResponseDTO] = []
    var order: PostListOrder = .createdAt
    var isFirstLoading: Bool = false
    var isPaginating: Bool = false
    var hasLoadedOnce: Bool = false
    /// FeedFeature 동일 컨벤션: "0"은 더 이상 페이지가 없다는 sentinel.
    var nextCursor: String = "0"
    var errorMessage: String?

    var isLocationDenied: Bool = false
    var currentLatitude: Double?
    var currentLongitude: Double?

    /// Post 도메인 내부에서 직접 push하는 자식 화면들. NavigationStack 1단계 깊이로 한정.
    /// 더 깊은 계층(Detail에서 UserPosts 등)은 Tier 3에서 별도 라우팅 정의.
    var detail: PostDetailFeature.State?
    var write: PostWriteFeature.State?
    var search: PostSearchFeature.State?

    /// 미디어 풀스크린 viewer. nil이 아니면 `fullScreenCover`로 노출.
    var mediaPreview: MediaPreviewItem?

    /// Post 메인의 카드 작성자 탭으로 진입한 다른 사용자의 게시글 목록.
    var userPostsList: UserPostsFeature.State?
  }

  enum Action: BindableAction, Sendable {
    case binding(BindingAction<State>)
    case task
    case unauthenticatedSkipped
    case locationResolved(latitude: Double, longitude: Double, isDenied: Bool)
    case orderTabTapped(PostListOrder)
    case lastCardAppeared(postID: String)
    case cardTapped(postID: String)
    case cardLikeToggled(postID: String, currentIsLike: Bool)
    case mediaTapped(MediaPreviewItem)
    case mediaPreviewDismissed
    case authorTapped(userID: String)
    case searchEntryTapped
    case writeButtonTapped
    case locationPermissionBannerTapped
    case loadFirstPageResponse(Result<PostSummaryPaginationResponseDTO, Error>)
    case loadMoreResponse(Result<PostSummaryPaginationResponseDTO, Error>)
    case likeToggleResponse(postID: String, snapshot: LikeSnapshot, Result<LikeStatusResponse, Error>)
    case detail(PostDetailFeature.Action)
    case detailDismissed
    case write(PostWriteFeature.Action)
    case writeDismissed
    case search(PostSearchFeature.Action)
    case searchDismissed
    case userPostsList(UserPostsFeature.Action)
    case userPostsListDismissed
    case delegate(Delegate)

    enum Delegate: Equatable, Sendable {}
  }

  /// 좋아요 optimistic 토글 전 원본 값을 저장해 실패/서버 보정 시 baseline 기준으로 정확히 복원한다.
  struct LikeSnapshot: Equatable, Sendable {
    let isLike: Bool
    let likeCount: Double
  }

  private static let firstPageLimit = 10
  /// FeedFeature와 동일하게 "0"을 다음 페이지 종료 sentinel로 사용.
  private static let endCursor = "0"

  var body: some Reducer<State, Action> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .binding:
        return .none

      case .task:
        return handleTaskAction(state: &state)

      case .unauthenticatedSkipped:
        // hasLoadedOnce=false 유지로 재인증 후 재진입 시 task가 다시 실행되도록 한다.
        state.isFirstLoading = false
        state.hasLoadedOnce = false
        return .none

      case let .locationResolved(latitude, longitude, isDenied):
        state.currentLatitude = latitude
        state.currentLongitude = longitude
        state.isLocationDenied = isDenied
        return loadFirstPage(state: &state)

      case let .orderTabTapped(order):
        guard state.order != order else { return .none }
        state.order = order
        state.posts = []
        state.nextCursor = Self.endCursor
        return loadFirstPage(state: &state)

      case let .lastCardAppeared(postID):
        return handleLastCardAppeared(state: &state, postID: postID)

      case let .cardTapped(postID):
        state.detail = PostDetailFeature.State(postID: postID)
        return .none

      case let .mediaTapped(item):
        state.mediaPreview = item
        return .none

      case .mediaPreviewDismissed:
        state.mediaPreview = nil
        return .none

      case let .cardLikeToggled(postID, currentIsLike):
        return handleCardLikeToggled(state: &state, postID: postID, currentIsLike: currentIsLike)

      case let .authorTapped(userID):
        state.userPostsList = UserPostsFeature.State(userID: userID)
        return .none

      case .searchEntryTapped:
        state.search = PostSearchFeature.State()
        return .none

      case .writeButtonTapped:
        state.write = PostWriteFeature.State()
        return .none

      case .locationPermissionBannerTapped:
        return .none

      case let .loadFirstPageResponse(.success(response)):
        state.isFirstLoading = false
        state.hasLoadedOnce = true
        state.errorMessage = nil
        state.posts = response.data
        state.nextCursor = Self.normalizedCursor(
          previousCursor: nil,
          itemsEmpty: response.data.isEmpty,
          rawNextCursor: response.nextCursor
        )
        return .none

      case let .loadFirstPageResponse(.failure(error)):
        state.isFirstLoading = false
        state.hasLoadedOnce = true
        state.errorMessage = Self.userFacingMessage(for: error)
        return .none

      case let .loadMoreResponse(.success(response)):
        state.isPaginating = false
        let previousCursor = state.nextCursor
        let existingIDs = Set(state.posts.map(\.postID))
        let newItems = response.data.filter { !existingIDs.contains($0.postID) }
        state.posts.append(contentsOf: newItems)
        state.nextCursor = Self.normalizedCursor(
          previousCursor: previousCursor,
          itemsEmpty: newItems.isEmpty,
          rawNextCursor: response.nextCursor
        )
        return .none

      case let .loadMoreResponse(.failure(error)):
        state.isPaginating = false
        state.errorMessage = Self.userFacingMessage(for: error)
        return .none

      case let .likeToggleResponse(postID, snapshot, .success(response)):
        guard let index = state.posts.firstIndex(where: { $0.postID == postID }) else {
          return .none
        }
        let confirmed = response.likeStatus
        // baseline(snapshot)을 기준으로 절대 보정해 누적 오차를 차단한다.
        // snapshot.isLike == confirmed면 변동 없음, 다르면 ±1 만 적용.
        let baseline = snapshot.likeCount
        let delta: Double = (confirmed == snapshot.isLike) ? 0 : (confirmed ? 1 : -1)
        let adjusted = max(0, baseline + delta)
        let post = state.posts[index]
        state.posts[index] = post.applyingLike(isLike: confirmed, likeCount: adjusted)
        return .none

      case let .likeToggleResponse(postID, snapshot, .failure):
        guard let index = state.posts.firstIndex(where: { $0.postID == postID }) else {
          return .none
        }
        let post = state.posts[index]
        state.posts[index] = post.applyingLike(
          isLike: snapshot.isLike,
          likeCount: snapshot.likeCount
        )
        return .none

      // MARK: - Detail
      case let .detail(.delegate(.dismiss)):
        state.detail = nil
        return .none

      case let .detail(.delegate(.editRequested(_, post))):
        state.detail = nil
        state.write = PostWriteFeature.State(post: post)
        return .none

      case let .detail(.delegate(.userPostsRequested(userID))):
        state.detail = nil
        state.userPostsList = UserPostsFeature.State(userID: userID)
        return .none

      case let .detail(.delegate(.postDeleted(postID))):
        // 게시글 삭제 → 메인 리스트에서도 제거.
        state.posts.removeAll { $0.postID == postID }
        return .none

      case let .detail(.delegate(.likeStatusChanged(postID, isLike, likeCount))):
        // Detail에서 좋아요 변동 → 메인 리스트 카드 동기화.
        if let index = state.posts.firstIndex(where: { $0.postID == postID }) {
          let post = state.posts[index]
          state.posts[index] = post.applyingLike(isLike: isLike, likeCount: likeCount)
        }
        return .none

      case .detail:
        return .none

      case .detailDismissed:
        state.detail = nil
        return .none

      // MARK: - Write
      case .write(.delegate(.dismiss)):
        state.write = nil
        return .none

      case let .write(.delegate(.postCreated(post))):
        state.write = nil
        // 새 게시글을 메인 리스트 최상단에 즉시 반영.
        let summary = PostSummaryResponseDTO.from(post)
        if !state.posts.contains(where: { $0.postID == summary.postID }) {
          state.posts.insert(summary, at: 0)
        }
        return .none

      case let .write(.delegate(.postUpdated(post))):
        state.write = nil
        // 수정된 게시글을 리스트에 반영. Detail로 다시 들어가지 않고 메인만 갱신.
        if let index = state.posts.firstIndex(where: { $0.postID == post.postID }) {
          state.posts[index] = PostSummaryResponseDTO.from(post)
        }
        return .none

      case let .write(.delegate(.locationSelectRequested(latitude, longitude))):
        // Tier 3에서 PostLocationSelectFeature 도입 시 여기서 화면 push.
        // 현재는 임시로 좌표 미설정인 경우 서울 시청을 채우고 placeholder 처리.
        _ = (latitude, longitude)
        state.write?.locationSelected(
          latitude: PostLocationFallback.seoulCityHall.latitude,
          longitude: PostLocationFallback.seoulCityHall.longitude,
          address: "서울 시청 (임시)"
        )
        return .none

      case .write:
        return .none

      case .writeDismissed:
        state.write = nil
        return .none

      // MARK: - Search
      case .search(.delegate(.dismiss)):
        state.search = nil
        return .none

      case let .search(.delegate(.postDetailRequested(postID))):
        // Search 결과에서 카드 탭 → 같은 NavigationStack의 다음 단계로 Detail push.
        // Search 화면은 닫고 Detail만 push되도록 한다.
        state.search = nil
        state.detail = PostDetailFeature.State(postID: postID)
        return .none

      case .search:
        return .none

      case .searchDismissed:
        state.search = nil
        return .none

      // MARK: - UserPosts (다른 사용자 게시글 목록)
      case let .userPostsList(.delegate(.postDetailRequested(postID))):
        // UserPosts 카드 탭 → 같은 NavigationStack에 Detail push.
        state.userPostsList = nil
        state.detail = PostDetailFeature.State(postID: postID)
        return .none

      case .userPostsList(.delegate(.dismiss)):
        state.userPostsList = nil
        return .none

      case .userPostsList:
        return .none

      case .userPostsListDismissed:
        state.userPostsList = nil
        return .none

      case .delegate:
        return .none
      }
    }
    .ifLet(\.detail, action: \.detail) {
      PostDetailFeature()
    }
    .ifLet(\.write, action: \.write) {
      PostWriteFeature()
    }
    .ifLet(\.search, action: \.search) {
      PostSearchFeature()
    }
    .ifLet(\.userPostsList, action: \.userPostsList) {
      UserPostsFeature()
    }
  }

}

// MARK: - Effect handlers / helpers

private extension PostFeature {
  func handleTaskAction(state: inout State) -> Effect<Action> {
    guard !state.hasLoadedOnce else { return .none }
    state.isFirstLoading = true
    state.errorMessage = nil

    let sessionClient = sessionClient
    let locationClient = locationClient

    return .run { send in
      let snapshot = await sessionClient.snapshot()

      // 비인증 상태(토큰 없음)에서는 위치 권한 다이얼로그/listGeolocation 호출을 모두 skip.
      guard !snapshot.accessToken.isEmpty else {
        await send(.unauthenticatedSkipped)
        return
      }

      let initialStatus = await locationClient.currentAuthorizationStatus()
      let resolvedStatus: CLAuthorizationStatus
      if initialStatus == .notDetermined {
        resolvedStatus = await locationClient.requestAuthorization()
      } else {
        resolvedStatus = initialStatus
      }

      switch resolvedStatus {
      case .authorizedWhenInUse, .authorizedAlways:
        do {
          let coordinate = try await locationClient.currentLocation()
          await send(
            .locationResolved(
              latitude: coordinate.latitude,
              longitude: coordinate.longitude,
              isDenied: false
            )
          )
        } catch {
          await send(
            .locationResolved(
              latitude: PostLocationFallback.seoulCityHall.latitude,
              longitude: PostLocationFallback.seoulCityHall.longitude,
              isDenied: false
            )
          )
        }
      default:
        await send(
          .locationResolved(
            latitude: PostLocationFallback.seoulCityHall.latitude,
            longitude: PostLocationFallback.seoulCityHall.longitude,
            isDenied: true
          )
        )
      }
    }
    // cancelInFlight=false: SwiftUI .task 재실행 race를 hasLoadedOnce 가드로 idempotent 처리.
    .cancellable(id: "PostFeature.task", cancelInFlight: false)
  }

  func handleLastCardAppeared(state: inout State, postID: String) -> Effect<Action> {
    guard
      !state.isFirstLoading,
      !state.isPaginating,
      state.nextCursor != Self.endCursor,
      state.posts.last?.postID == postID
    else {
      return .none
    }
    state.isPaginating = true

    let postClient = postClient
    let cursor = state.nextCursor
    // "0"은 sentinel이므로 백엔드에 그대로 보내면 안 된다.
    let nextParameter: String? = cursor.isEmpty ? nil : cursor
    let query = GeolocationPostsQuery(
      category: nil,
      longitude: state.currentLongitude,
      latitude: state.currentLatitude,
      maxDistance: nil,
      limit: nil,
      next: nextParameter,
      orderBy: state.order.apiValue
    )

    return .run { send in
      await send(
        .loadMoreResponse(
          Result {
            try await postClient.listGeolocation(query)
          }
        )
      )
    }
    .cancellable(id: "PostFeature.loadMore", cancelInFlight: true)
  }

  func handleCardLikeToggled(
    state: inout State,
    postID: String,
    currentIsLike: Bool
  ) -> Effect<Action> {
    guard let index = state.posts.firstIndex(where: { $0.postID == postID }) else {
      return .none
    }
    let original = state.posts[index]
    let snapshot = LikeSnapshot(isLike: original.isLike, likeCount: original.likeCount)
    let targetStatus = !currentIsLike
    state.posts[index] = original.applyingLike(
      isLike: targetStatus,
      likeCount: max(0, original.likeCount + (targetStatus ? 1 : -1))
    )

    let postClient = postClient

    return .run { send in
      await send(
        .likeToggleResponse(
          postID: postID,
          snapshot: snapshot,
          Result {
            try await postClient.setLike(postID, targetStatus)
          }
        )
      )
    }
    .cancellable(id: "PostFeature.like.\(postID)", cancelInFlight: true)
  }

  /// 권한/정렬 변경 직후 호출되는 첫 페이지 로드. 좌표 미정 시 fallback 좌표 사용.
  func loadFirstPage(state: inout State) -> Effect<Action> {
    state.isFirstLoading = true
    state.isPaginating = false
    state.errorMessage = nil

    let postClient = postClient
    let latitude = state.currentLatitude ?? PostLocationFallback.seoulCityHall.latitude
    let longitude = state.currentLongitude ?? PostLocationFallback.seoulCityHall.longitude
    let query = GeolocationPostsQuery(
      category: nil,
      longitude: longitude,
      latitude: latitude,
      maxDistance: nil,
      limit: Self.firstPageLimit,
      next: nil,
      orderBy: state.order.apiValue
    )

    return .run { send in
      await send(
        .loadFirstPageResponse(
          Result {
            try await postClient.listGeolocation(query)
          }
        )
      )
    }
    .cancellable(id: "PostFeature.loadFirst", cancelInFlight: true)
  }

  /// 응답 cursor를 sentinel 규약("0" = 종료)에 맞춰 정규화.
  static func normalizedCursor(
    previousCursor: String?,
    itemsEmpty: Bool,
    rawNextCursor: String?
  ) -> String {
    let raw = rawNextCursor ?? ""
    if raw.isEmpty {
      return endCursor
    }
    if raw == endCursor {
      return endCursor
    }
    if itemsEmpty, let previousCursor, previousCursor == raw {
      return endCursor
    }
    return raw
  }

  static func userFacingMessage(for error: Error) -> String {
    if let apiError = error as? APIError {
      switch apiError {
      case let .invalidBaseURL(message),
           let .invalidURL(message),
           let .transport(message),
           let .decoding(message):
        return message

      case .missingAccessToken, .missingRefreshToken:
        return "인증 정보가 없어 게시글을 불러올 수 없어요."

      case let .invalidSession(statusCode):
        return "세션이 유효하지 않습니다. 다시 로그인해 주세요. (\(statusCode))"

      case let .server(statusCode, message, _):
        if let message, !message.isEmpty {
          return message
        }
        return "게시글 응답을 불러오지 못했어요. (\(statusCode))"
      }
    }
    return "게시글을 불러오지 못했어요. 잠시 후 다시 시도해 주세요."
  }
}

private extension PostSummaryResponseDTO {
  /// 좋아요 토글 시 isLike/likeCount만 교체한 새 값을 반환. DTO가 let으로 선언되어 있어 helper 필요.
  func applyingLike(isLike: Bool, likeCount: Double) -> PostSummaryResponseDTO {
    PostSummaryResponseDTO(
      postID: postID,
      category: category,
      title: title,
      content: content,
      geolocation: geolocation,
      creator: creator,
      files: files,
      isLike: isLike,
      likeCount: likeCount,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }

  /// PostResponseDTO(상세 응답)를 메인 리스트용 summary로 변환. comments 필드만 누락된 동일 구조.
  static func from(_ post: PostResponseDTO) -> PostSummaryResponseDTO {
    PostSummaryResponseDTO(
      postID: post.postID,
      category: post.category,
      title: post.title,
      content: post.content,
      geolocation: post.geolocation,
      creator: post.creator,
      files: post.files,
      isLike: post.isLike,
      likeCount: post.likeCount,
      createdAt: post.createdAt,
      updatedAt: post.updatedAt
    )
  }
}
