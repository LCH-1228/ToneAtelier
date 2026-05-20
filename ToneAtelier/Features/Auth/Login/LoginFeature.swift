//
//  LoginFeature.swift
//  ToneAtelier
//
//  Created by Codex on 4/23/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct LoginFeature {
  enum Notice: Equatable, Sendable {
    case reauthenticationRequired
    case sessionExpired

    init?(sessionInvalidationReason: SessionInvalidationReason) {
      switch sessionInvalidationReason {
      case .accessTokenRejected, .refreshTokenRejected:
        self = .reauthenticationRequired
      case .expired:
        self = .sessionExpired
      }
    }

    var message: String {
      switch self {
      case .reauthenticationRequired:
        return "인증 정보가 유효하지 않아 다시 로그인해 주세요."
      case .sessionExpired:
        return "세션이 만료되어 다시 로그인해 주세요."
      }
    }
  }

  @ObservableState
  struct State: Equatable {
    @Presents var alert: AlertState<Action.Alert>?
    var id = ""
    var password = ""
    var isAppleLoginInProgress = false
    var isEmailLoginInProgress = false
    var isKakaoLoginInProgress = false
    var notice: Notice?

    init(notice: Notice? = nil) {
      self.notice = notice
    }
  }

  enum Action: BindableAction, Sendable {
    case alert(PresentationAction<Alert>)
    case appleLoginButtonTapped
    case appleLoginResponse(Result<AuthenticatedUserResponse, any Error>)
    case binding(BindingAction<State>)
    case delegate(Delegate)
    case emailLoginResponse(Result<AuthenticatedUserResponse, any Error>)
    case kakaoLoginButtonTapped
    case kakaoLoginResponse(Result<AuthenticatedUserResponse, any Error>)
    case loginButtonTapped
    case noticeDismissed

    enum Alert: Equatable, Sendable {}

    enum Delegate: Equatable, Sendable {
      case authenticated
    }
  }

  @Dependency(\.appleAuthClient) private var appleAuthClient
  @Dependency(\.kakaoAuthClient) private var kakaoAuthClient
  @Dependency(\.pushTokenClient) private var pushTokenClient
  @Dependency(\.sessionClient) private var sessionClient
  @Dependency(\.userClient) private var userClient

  var body: some Reducer<State, Action> {
    BindingReducer()

    Reduce { state, action in
      switch action {
      case .alert:
        return .none

      case .appleLoginButtonTapped:
        guard !state.isAppleLoginInProgress else { return .none }

        state.isAppleLoginInProgress = true
        state.notice = nil
        let appleAuthClient = appleAuthClient
        let pushTokenClient = pushTokenClient
        let userClient = userClient

        return .run { send in
          do {
            let token = await pushTokenClient.current()
            let idToken = try await appleAuthClient.login()
            let response = try await userClient.loginApple(
              AppleLoginRequestDTO(
                idToken: idToken,
                deviceToken: token
              )
            )
            await send(.appleLoginResponse(.success(response)))
          } catch {
            await send(.appleLoginResponse(.failure(error)))
          }
        }

      case let .appleLoginResponse(.success(response)):
        state.isAppleLoginInProgress = false
        let sessionClient = sessionClient
        let userID = response.userID
        return .run { send in
          await sessionClient.updateCurrentUserID(userID)
          await send(.delegate(.authenticated))
        }

      case let .appleLoginResponse(.failure(error)):
        state.isAppleLoginInProgress = false
        guard !error.isRequestCancellation else { return .none }
        state.showAlert("Apple 로그인 실패: \(error.localizedDescription)")
        return .none

      case .binding:
        return .none

      case .delegate:
        return .none

      case let .emailLoginResponse(.success(response)):
        state.isEmailLoginInProgress = false
        let sessionClient = sessionClient
        let userID = response.userID
        return .run { send in
          await sessionClient.updateCurrentUserID(userID)
          await send(.delegate(.authenticated))
        }

      case let .emailLoginResponse(.failure(error)):
        state.isEmailLoginInProgress = false
        guard !error.isRequestCancellation else { return .none }
        state.showAlert("로그인 실패: \(error.localizedDescription)")
        return .none

      case .kakaoLoginButtonTapped:
        guard !state.isKakaoLoginInProgress else { return .none }

        state.isKakaoLoginInProgress = true
        state.notice = nil
        let kakaoAuthClient = kakaoAuthClient
        let pushTokenClient = pushTokenClient
        let userClient = userClient

        return .run { send in
          do {
            let token = await pushTokenClient.current()
            let oauthToken = try await kakaoAuthClient.login()
            let response = try await userClient.loginKakao(
              KakaoLoginRequestDTO(
                oauthToken: oauthToken,
                deviceToken: token
              )
            )
            await send(.kakaoLoginResponse(.success(response)))
          } catch {
            await send(.kakaoLoginResponse(.failure(error)))
          }
        }

      case let .kakaoLoginResponse(.success(response)):
        state.isKakaoLoginInProgress = false
        let sessionClient = sessionClient
        let userID = response.userID
        return .run { send in
          await sessionClient.updateCurrentUserID(userID)
          await send(.delegate(.authenticated))
        }

      case let .kakaoLoginResponse(.failure(error)):
        state.isKakaoLoginInProgress = false
        guard !error.isRequestCancellation else { return .none }
        state.showAlert("카카오 로그인 실패: \(error.localizedDescription)")
        return .none

      case .loginButtonTapped:
        guard !state.isEmailLoginInProgress else { return .none }

        state.notice = nil
        let email = state.id.trimmed
        let password = state.password.trimmed

        guard !email.isEmpty else {
          state.showAlert("아이디를 입력해 주세요.")
          return .none
        }

        guard !password.isEmpty else {
          state.showAlert("비밀번호를 입력해 주세요.")
          return .none
        }

        state.isEmailLoginInProgress = true
        let pushTokenClient = pushTokenClient
        let userClient = userClient

        return .run { send in
          do {
            let token = await pushTokenClient.current()
            let response = try await userClient.login(
              EmailLoginRequestDTO(
                email: email,
                password: password,
                deviceToken: token
              )
            )
            await send(.emailLoginResponse(.success(response)))
          } catch {
            await send(.emailLoginResponse(.failure(error)))
          }
        }

      case .noticeDismissed:
        state.notice = nil
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
  }
}

private extension LoginFeature.State {
  mutating func showAlert(_ message: String) {
    alert = AlertState {
      TextState(message)
    }
  }
}

private extension Error {
  var isRequestCancellation: Bool {
    if self is CancellationError {
      return true
    }

    guard let urlError = self as? URLError else { return false }
    return urlError.code == .cancelled
  }
}
