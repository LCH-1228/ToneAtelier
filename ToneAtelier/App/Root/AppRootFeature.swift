//
//  AppRootFeature.swift
//  ToneAtelier
//
//  Created by Codex on 4/23/26.
//

import ComposableArchitecture
import Foundation
import OSLog

// swiftlint:disable type_body_length file_length

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

    nonisolated private static let generic = BootstrapFailure(
      title: "세션을 확인하지 못했어요.",
      message: "잠시 후 다시 시도해 주세요."
    )

    nonisolated private static let network = BootstrapFailure(
      title: "네트워크 연결이 불안정해요.",
      message: "연결 상태를 확인한 뒤 다시 시도해 주세요."
    )

    nonisolated private static func message(for statusCode: Int) -> BootstrapFailure {
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
    var launchScreen = LaunchScreenFeature.State()
    var login = LoginFeature.State()
    var mainTab = MainTabFeature.State()
    var pendingBootstrap: PendingBootstrap?
    var splashReady = false
  }

  enum PendingBootstrap: Equatable, Sendable {
    case authenticated
    case unauthenticated(LoginFeature.Notice?)
  }

  enum Action: Sendable {
    case becameActive
    case bootstrapResponse(BootstrapResponse)
    case launchScreen(LaunchScreenFeature.Action)
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
  @Dependency(\.chatPushClient) private var chatPushClient
  @Dependency(\.chatUnreadCenter) private var chatUnreadCenter
  @Dependency(\.commerceClient) private var commerceClient
  @Dependency(\.imageClient) private var imageClient
  @Dependency(\.paymentReceiptStore) private var paymentReceiptStore
  @Dependency(\.pushTokenClient) private var pushTokenClient
  @Dependency(\.sessionClient) private var sessionClient
  @Dependency(\.userClient) private var userClient

  var body: some Reducer<State, Action> {
    Scope(state: \.launchScreen, action: \.launchScreen) {
      LaunchScreenFeature()
    }

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

        let chatUnreadCenter = chatUnreadCenter
        let commerceClient = commerceClient
        let paymentReceiptStore = paymentReceiptStore
        let pushTokenClient = pushTokenClient
        let sessionClient = sessionClient
        let userClient = userClient

        return .merge(
          bootstrapSession(),
          .run { _ in
            await chatUnreadCenter.bootstrap()
          },
          .run { _ in
            await Self.reconcilePendingReceipts(
              paymentReceiptStore: paymentReceiptStore,
              commerceClient: commerceClient
            )
          }
          .cancellable(id: "AppRootFeature.paymentReconcile", cancelInFlight: true),
          .run { _ in
            for await _ in await NetworkReachability.shared.recoveries() {
              await Self.reconcilePendingReceipts(
                paymentReceiptStore: paymentReceiptStore,
                commerceClient: commerceClient
              )
            }
          }
          .cancellable(id: "AppRootFeature.networkReconcile", cancelInFlight: true),
          .run { send in
            let events = await sessionClient.events()

            for await event in events {
              await send(.sessionEventReceived(event))
            }
          }
          .cancellable(id: "AppRootFeature.sessionEvents", cancelInFlight: true),
          .run { _ in
            let stream = pushTokenClient.tokenUpdates()
            for await token in stream {
              let snapshot = await sessionClient.snapshot()
              guard snapshot.hasAuthenticatedSession else { continue }
              guard await DeviceTokenSyncCenter.shared.shouldSync(token) else { continue }
              do {
                _ = try await userClient.updateDeviceToken(.init(deviceToken: token))
                await DeviceTokenSyncCenter.shared.markSent(token)
                Logger.authSession.notice("Device token updated on server")
              } catch {
                Logger.authSession.error(
                  "updateDeviceToken failed: \(error.localizedDescription, privacy: .private)"
                )
              }
            }
          }
          .cancellable(id: "AppRootFeature.pushTokenUpdates", cancelInFlight: true)
        )

      case .becameActive:
        let chatUnreadCenter = chatUnreadCenter
        return .run { _ in await chatUnreadCenter.catchUp() }

      case .bootstrapResponse(.authenticated):
        state.bootstrapFailure = nil
        if state.splashReady {
          state.isAuthenticated = true
          state.isSessionLoading = false
          return .merge(
            syncDeviceTokenIfAvailable(),
            consumePendingPushIfAny()
          )
        } else {
          state.pendingBootstrap = .authenticated
          return .none
        }

      case let .bootstrapResponse(.retryableFailure(failure)):
        // 실패는 splash 최소 시간을 무시하고 즉시 retry 화면으로 전환한다.
        state.bootstrapFailure = failure
        state.isAuthenticated = false
        state.isSessionLoading = false
        state.pendingBootstrap = nil
        state.mainTab = MainTabFeature.State()
        return .none

      case let .bootstrapResponse(.unauthenticated(notice)):
        state.bootstrapFailure = nil
        // 사용자 단위 캐시는 보안 차원에서 splash 대기와 무관하게 즉시 비운다.
        let chatLocalStore = chatLocalStore
        let chatUnreadCenter = chatUnreadCenter
        let imageClient = imageClient
        let paymentReceiptStore = paymentReceiptStore
        let cacheClearEffect: Effect<Action> = .run { _ in
          await chatUnreadCenter.clearAll()
          do {
            try await chatLocalStore.clearAll()
          } catch {
            let detail = error.localizedDescription
            Logger.authSession.error(
              "Chat local cache clear failed during bootstrap unauthenticated. error=\(detail, privacy: .private)"
            )
          }
          await imageClient.clearCache()
          await paymentReceiptStore.clearAll()
          await DeviceTokenSyncCenter.shared.reset()
        }
        if state.splashReady {
          state.resetToUnauthenticated(notice: notice)
          return cacheClearEffect
        } else {
          state.pendingBootstrap = .unauthenticated(notice)
          return cacheClearEffect
        }

      case .login(.delegate(.authenticated)):
        state.bootstrapFailure = nil
        state.isAuthenticated = true
        state.isSessionLoading = false
        return .merge(
          syncDeviceTokenIfAvailable(),
          consumePendingPushIfAny()
        )

      case .logoutCompleted:
        state.resetToUnauthenticated()
        return .none

      case .mainTab(.delegate(.logoutRequested)):
        let sessionClient = sessionClient
        let userClient = userClient
        let chatLocalStore = chatLocalStore
        let chatUnreadCenter = chatUnreadCenter
        let imageClient = imageClient
        let paymentReceiptStore = paymentReceiptStore
        let pushTokenClient = pushTokenClient

        return .run { send in
          do {
            _ = try await userClient.logout()
          } catch {
            Logger.authSession.error(
              "Server logout failed; clearing local session. error=\(error.localizedDescription, privacy: .private)"
            )
          }

          await sessionClient.clearTokens()
          // 다음 사용자 계정에 잔존 토큰이 묶이지 않도록 push token을 비운다.
          await pushTokenClient.clear()
          await DeviceTokenSyncCenter.shared.reset()
          await chatUnreadCenter.clearAll()
          await paymentReceiptStore.clearAll()
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
        state.splashReady = false
        state.pendingBootstrap = nil
        state.launchScreen = LaunchScreenFeature.State()
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
        let chatUnreadCenter = chatUnreadCenter
        let imageClient = imageClient
        let paymentReceiptStore = paymentReceiptStore
        return .run { _ in
          await chatUnreadCenter.clearAll()
          do {
            try await chatLocalStore.clearAll()
          } catch {
            let detail = error.localizedDescription
            Logger.authSession.error(
              "Chat local cache clear failed during session invalidation. error=\(detail, privacy: .private)"
            )
          }
          await imageClient.clearCache()
          await paymentReceiptStore.clearAll()
          await DeviceTokenSyncCenter.shared.reset()
        }

      case .launchScreen(.delegate(.ready)):
        state.splashReady = true
        guard let pending = state.pendingBootstrap else { return .none }
        state.pendingBootstrap = nil
        switch pending {
        case .authenticated:
          state.isAuthenticated = true
          state.isSessionLoading = false
          return .merge(
            syncDeviceTokenIfAvailable(),
            consumePendingPushIfAny()
          )
        case let .unauthenticated(notice):
          state.resetToUnauthenticated(notice: notice)
          return .none
        }

      case .launchScreen, .login, .mainTab:
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
  /// 인증 완료 직후 cold-launch push pending 을 즉시 소비해 chat 탭 deep-link.
  /// MainTabView mount 후 .task 시작 사이의 SwiftUI 라이프사이클 race 를 회피한다.
  func consumePendingPushIfAny() -> Effect<Action> {
    let chatPushClient = chatPushClient
    return .run { send in
      if let pendingRoomID = await chatPushClient.consumePending() {
        await send(.mainTab(.pushTapped(roomID: pendingRoomID)))
      }
    }
  }

  func syncDeviceTokenIfAvailable() -> Effect<Action> {
    let pushTokenClient = pushTokenClient
    let userClient = userClient
    return .run { _ in
      guard let token = await pushTokenClient.current(), !token.isEmpty else { return }
      guard await DeviceTokenSyncCenter.shared.shouldSync(token) else { return }
      do {
        _ = try await userClient.updateDeviceToken(.init(deviceToken: token))
        await DeviceTokenSyncCenter.shared.markSent(token)
        Logger.authSession.notice("Device token synced after authentication")
      } catch {
        Logger.authSession.error(
          "Device token sync failed: \(error.localizedDescription, privacy: .private)"
        )
      }
    }
  }

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
      await sessionClient.updateCurrentUserID(profile.userID)
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

  static func reconcilePendingReceipts(
    paymentReceiptStore: PaymentReceiptStore,
    commerceClient: CommerceClient
  ) async {
    let receipts = await paymentReceiptStore.loadAll()
    for receipt in receipts {
      guard let impUID = receipt.impUID else { continue }
      let request = PaymentValidationRequestDTO(impUID: impUID, filterID: receipt.filterID)
      do {
        _ = try await commerceClient.validatePayment(request)
        await paymentReceiptStore.remove(receipt.merchantUID)
        Logger.payment.notice("auto reconcile success merchant=\(receipt.merchantUID, privacy: .public)")
      } catch {
        Logger.payment.error("auto reconcile failed merchant=\(receipt.merchantUID, privacy: .public)")
      }
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

private actor DeviceTokenSyncCenter {
  static let shared = DeviceTokenSyncCenter()
  private var lastSentToken: String?

  func shouldSync(_ token: String) -> Bool {
    token != lastSentToken
  }

  func markSent(_ token: String) {
    lastSentToken = token
  }

  func reset() {
    lastSentToken = nil
  }
}
