//
//  AppRootFeature.swift
//  ToneAtelier
//
//  Created by Codex on 4/23/26.
//

import ComposableArchitecture
import Foundation
import OSLog

@Reducer
struct AppRootFeature {
  struct BootstrapFailure: Equatable, Sendable {
    let title: String
    let message: String

    nonisolated static func from(error: Error) -> Self {
      guard let apiError = error as? APIError else {
        return .generic
      }

      switch apiError {
      case .transport:
        return .network
      case let .server(statusCode, _, _):
        return message(for: statusCode)
      default:
        return .generic
      }
    }

    private nonisolated static let generic = BootstrapFailure(
      title: "세션을 확인하지 못했어요.",
      message: "잠시 후 다시 시도해 주세요."
    )

    private nonisolated static let network = BootstrapFailure(
      title: "네트워크 연결이 불안정해요.",
      message: "연결 상태를 확인한 뒤 다시 시도해 주세요."
    )

    private nonisolated static func message(for statusCode: Int) -> BootstrapFailure {
      switch statusCode {
      case 403:
        return BootstrapFailure(
          title: "세션 확인 요청이 거부됐어요.",
          message: "다시 시도해 주세요."
        )
      case 420:
        return BootstrapFailure(
          title: "앱 인증 정보를 확인하지 못했어요.",
          message: "다시 시도해 주세요."
        )
      case 429:
        return BootstrapFailure(
          title: "요청이 너무 많아요.",
          message: "잠시 후 다시 시도해 주세요."
        )
      case 444:
        return BootstrapFailure(
          title: "잘못된 요청으로 세션 확인에 실패했어요.",
          message: "다시 시도해 주세요."
        )
      case 500:
        return BootstrapFailure(
          title: "서버 문제로 세션 확인이 지연되고 있어요.",
          message: "잠시 후 다시 시도해 주세요."
        )
      default:
        return .generic
      }
    }
  }

  @ObservableState
  struct State: Equatable {
    var bootstrapFailure: BootstrapFailure?
    var isAuthenticated = false
    var isSessionLoading = true
    var login = LoginFeature.State()
    var mainTab = MainTabFeature.State()
  }

  enum Action: Sendable {
    case bootstrapResponse(BootstrapResponse)
    case login(LoginFeature.Action)
    case logoutCompleted
    case mainTab(MainTabFeature.Action)
    case retryBootstrapButtonTapped
    case sessionEventReceived(SessionEvent)
    case task
  }

  enum BootstrapResponse: Equatable, Sendable {
    case authenticated
    case retryableFailure(BootstrapFailure)
    case unauthenticated(LoginFeature.Notice?)
  }

  @Dependency(\.authClient) private var authClient
  @Dependency(\.chatLocalStore) private var chatLocalStore
  @Dependency(\.imageClient) private var imageClient
  @Dependency(\.sessionClient) private var sessionClient
  @Dependency(\.userClient) private var userClient

  var body: some Reducer<State, Action> {
    Scope(state: \.login, action: \.login) {
      LoginFeature()
    }

    Scope(state: \.mainTab, action: \.mainTab) {
      MainTabFeature()
    }

    Reduce { state, action in
      switch action {
      case .task:
        state.isSessionLoading = true
        state.bootstrapFailure = nil

        return .merge(
          bootstrapSession(),
          .run { send in
            let events = await sessionClient.events()

            for await event in events {
              await send(.sessionEventReceived(event))
            }
          }
          .cancellable(id: "AppRootFeature.sessionEvents", cancelInFlight: true)
        )

      case .bootstrapResponse(.authenticated):
        state.bootstrapFailure = nil
        state.isAuthenticated = true
        state.isSessionLoading = false
        return .none

      case let .bootstrapResponse(.retryableFailure(failure)):
        state.bootstrapFailure = failure
        state.isAuthenticated = false
        state.isSessionLoading = false
        state.mainTab = MainTabFeature.State()
        return .none

      case let .bootstrapResponse(.unauthenticated(notice)):
        state.bootstrapFailure = nil
        state.resetToUnauthenticated(notice: notice)
        // 부트스트랩에서 토큰 만료/재인증 필요로 판정된 경로.
        // 사용자 단위 캐시인 채팅 로컬 스토어와 인증 이미지 캐시를 모두 비워
        // 다음 사용자에게 잔존 데이터가 노출되지 않도록 한다.
        let chatLocalStore = chatLocalStore
        let imageClient = imageClient
        return .run { _ in
          do {
            try await chatLocalStore.clearAll()
          } catch {
            Logger.authSession.error(
              "Chat local cache clear failed during bootstrap unauthenticated. error=\(error.localizedDescription, privacy: .private)"
            )
          }
          await imageClient.clearCache()
        }

      case .login(.delegate(.authenticated)):
        state.bootstrapFailure = nil
        state.isAuthenticated = true
        state.isSessionLoading = false
        return .none

      case .logoutCompleted:
        state.resetToUnauthenticated()
        return .none

      case .mainTab(.delegate(.logoutRequested)):
        let sessionClient = sessionClient
        let userClient = userClient
        let chatLocalStore = chatLocalStore
        let imageClient = imageClient

        return .run { send in
          do {
            _ = try await userClient.logout()
          } catch {
            Logger.authSession.error(
              "Server logout failed; clearing local session. error=\(error.localizedDescription, privacy: .private)"
            )
          }

          await sessionClient.clearTokens()
          // 로컬 채팅 캐시와 인증 이미지 캐시는 사용자 단위 데이터이므로 로그아웃 시 함께 비운다.
          // 실패해도 로그아웃 흐름은 진행돼야 한다.
          do {
            try await chatLocalStore.clearAll()
          } catch {
            Logger.authSession.error(
              "Chat local cache clear failed during logout. error=\(error.localizedDescription, privacy: .private)"
            )
          }
          await imageClient.clearCache()
          await send(.logoutCompleted)
        }

      case .retryBootstrapButtonTapped:
        state.bootstrapFailure = nil
        state.isSessionLoading = true
        return bootstrapSession()

      case .sessionEventReceived(.tokenRefreshed):
        // 토큰 갱신은 인증 상태 변화가 아니므로 root 흐름에서는 무시한다.
        // 장기 socket 연결을 가진 자식 피처(ChatRoom 등)가 직접 구독해 처리한다.
        return .none

      case let .sessionEventReceived(.invalidated(reason)):
        state.bootstrapFailure = nil
        state.resetToUnauthenticated(
          notice: LoginFeature.Notice(sessionInvalidationReason: reason)
        )
        // 서버 401/세션 만료로 자동 로그아웃되는 경로.
        // 사용자 단위 캐시인 채팅 로컬 스토어와 인증 이미지 캐시를 모두 비워
        // 다음 사용자에게 잔존 데이터가 노출되지 않도록 한다.
        let chatLocalStore = chatLocalStore
        let imageClient = imageClient
        return .run { _ in
          do {
            try await chatLocalStore.clearAll()
          } catch {
            Logger.authSession.error(
              "Chat local cache clear failed during session invalidation. error=\(error.localizedDescription, privacy: .private)"
            )
          }
          await imageClient.clearCache()
        }

      case .login, .mainTab:
        return .none
      }
    }
  }
}

private extension AppRootFeature.State {
  mutating func resetToUnauthenticated(notice: LoginFeature.Notice? = nil) {
    bootstrapFailure = nil
    isAuthenticated = false
    isSessionLoading = false
    login = LoginFeature.State(notice: notice)
    mainTab = MainTabFeature.State()
  }
}

private extension AppRootFeature {
  func bootstrapSession() -> Effect<Action> {
    let authClient = authClient
    let sessionClient = sessionClient
    let userClient = userClient

    return .run { send in
      let snapshot = await sessionClient.snapshot()

      guard snapshot.hasAuthenticatedSession else {
        if snapshot.hasAnySessionToken {
          await sessionClient.clearTokens()
        }
        await send(.bootstrapResponse(.unauthenticated(nil)))
        return
      }

      do {
        _ = try await authClient.refresh()
        await replenishCurrentUserIDIfNeeded(
          sessionClient: sessionClient,
          userClient: userClient
        )
        await send(.bootstrapResponse(.authenticated))
      } catch is CancellationError {
        return
      } catch let error as APIError {
        if let notice = loginNoticeForBootstrapFailure(error) {
          await sessionClient.clearTokens()
          await send(.bootstrapResponse(.unauthenticated(notice)))
          return
        }

        let failure = BootstrapFailure.from(error: error)
        await send(.bootstrapResponse(.retryableFailure(failure)))
      } catch {
        let failure = BootstrapFailure.from(error: error)
        await send(.bootstrapResponse(.retryableFailure(failure)))
      }
    }
  }

  func replenishCurrentUserIDIfNeeded(
    sessionClient: SessionClient,
    userClient: UserClient
  ) async {
    let snapshot = await sessionClient.snapshot()
    guard snapshot.currentUserID == nil else { return }

    do {
      let profile = try await userClient.fetchMyProfile()
      await sessionClient.updateCurrentUserID(profile.user_id)
    } catch is CancellationError {
      return
    } catch {
      Logger.authSession.notice(
        "Bootstrap currentUserID replenish skipped: \(error.localizedDescription, privacy: .private)"
      )
    }
  }

  nonisolated func loginNoticeForBootstrapFailure(_ error: APIError) -> LoginFeature.Notice? {
    switch error {
    case let .server(statusCode, _, _):
      return loginNoticeForBootstrapStatusCode(statusCode)
    case let .invalidSession(statusCode):
      return loginNoticeForBootstrapStatusCode(statusCode)
    default:
      return nil
    }
  }

  nonisolated func loginNoticeForBootstrapStatusCode(_ statusCode: Int) -> LoginFeature.Notice? {
    switch statusCode {
    case 401:
      return .reauthenticationRequired
    case 418:
      return .sessionExpired
    default:
      return nil
    }
  }
}

private extension SessionSnapshot {
  nonisolated var hasAuthenticatedSession: Bool {
    accessToken.isUsableSessionToken && refreshToken.isUsableSessionToken
  }

  nonisolated var hasAnySessionToken: Bool {
    accessToken.isUsableSessionToken || refreshToken.isUsableSessionToken
  }
}

private extension String {
  nonisolated var isUsableSessionToken: Bool {
    let value = trimmingCharacters(in: .whitespacesAndNewlines)
    return !value.isEmpty && !value.hasPrefix("$(")
  }
}
