//
//  JoinFeature.swift
//  ToneAtelier
//
//  Created by Codex on 4/23/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct JoinFeature {
  enum Step: Int, CaseIterable, Equatable, Sendable {
    case account
    case profile
  }

  @ObservableState
  struct State: Equatable {
    @Presents var alert: AlertState<Action.Alert>?
    var step: Step = .account
    var email = ""
    var isJoinCompleted = false
    var password = ""
    var passwordConfirmation = ""
    var nick = ""
    var name = ""
    var introduction = ""
    var phoneNumber = ""
    var hashTagsText = ""
    var isEmailValidated = false
    var validatedEmail = ""
    var isEmailValidationInProgress = false
    var isJoinInProgress = false
  }

  enum Action: BindableAction, Sendable {
    case alert(PresentationAction<Alert>)
    case binding(BindingAction<State>)
    case joinButtonTapped
    case joinResponse(Result<AuthenticatedUserResponse, any Error>)
    case nextButtonTapped
    case previousButtonTapped
    case validateEmailButtonTapped
    case validateEmailResponse(email: String, Result<MessageResponse, any Error>)

    enum Alert: Equatable, Sendable {}
  }

  @Dependency(\.sessionClient) private var sessionClient
  @Dependency(\.userClient) private var userClient

  var body: some Reducer<State, Action> {
    BindingReducer()

    Reduce { state, action in
      switch action {
      case .alert:
        return .none

      case .binding:
        let currentEmail = state.email.trimmed
        state.isEmailValidated = !currentEmail.isEmpty && state.validatedEmail == currentEmail
        return .none

      case .nextButtonTapped:
        guard state.validateAccountStep() else { return .none }
        state.step = .profile
        return .none

      case .previousButtonTapped:
        state.step = .account
        return .none

      case .joinButtonTapped:
        guard !state.isJoinInProgress else { return .none }

        guard state.validateAccountStep() else { return .none }
        guard state.validateProfileStep() else { return .none }

        let email = state.email.trimmed
        let password = state.password.trimmed
        let nick = state.nick.trimmed
        let name = state.name.trimmed

        state.isJoinInProgress = true
        let request = JoinRequestDTO(
          email: email,
          password: password,
          nick: nick,
          name: name,
          introduction: state.introduction.trimmed.nilIfEmpty,
          phoneNum: state.phoneNumber.trimmed.nilIfEmpty,
          hashTags: state.hashTags,
          deviceToken: nil
        )
        let userClient = userClient

        return .run { send in
          do {
            let response = try await userClient.join(request)
            await send(.joinResponse(.success(response)))
          } catch {
            await send(.joinResponse(.failure(error)))
          }
        }

      case let .joinResponse(.success(response)):
        state.isJoinInProgress = false
        state.isJoinCompleted = true
        let sessionClient = sessionClient
        let userID = response.user_id
        return .run { _ in
          await sessionClient.updateCurrentUserID(userID)
        }

      case let .joinResponse(.failure(error)):
        state.isJoinInProgress = false
        state.showAlert("회원가입 실패: \(error.localizedDescription)")
        return .none

      case .validateEmailButtonTapped:
        guard !state.isEmailValidationInProgress else { return .none }

        let email = state.email.trimmed

        guard !email.isEmpty else {
          state.showAlert("이메일을 입력해 주세요.")
          return .none
        }

        guard email.contains("@"), email.contains(".") else {
          state.showAlert("올바른 이메일 형식을 입력해 주세요.")
          return .none
        }

        state.isEmailValidationInProgress = true
        state.isEmailValidated = false
        let userClient = userClient

        return .run { send in
          do {
            let response = try await userClient.validateEmail(
              EmailValidationRequestDTO(email: email)
            )
            await send(.validateEmailResponse(email: email, .success(response)))
          } catch {
            await send(.validateEmailResponse(email: email, .failure(error)))
          }
        }

      case let .validateEmailResponse(email, .success(response)):
        state.isEmailValidationInProgress = false
        if state.email.trimmed == email {
          state.validatedEmail = email
          state.isEmailValidated = true
        }
        state.showAlert(response.message)
        return .none

      case let .validateEmailResponse(_, .failure(error)):
        state.isEmailValidationInProgress = false
        state.isEmailValidated = false
        state.showAlert("이메일 확인 실패: \(error.localizedDescription)")
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
  }
}

private extension JoinFeature.State {
  mutating func validateAccountStep() -> Bool {
    let email = email.trimmed
    let password = password.trimmed
    let passwordConfirmation = passwordConfirmation.trimmed

    guard !email.isEmpty else {
      showAlert("이메일을 입력해 주세요.")
      return false
    }

    guard email.contains("@"), email.contains(".") else {
      showAlert("올바른 이메일 형식을 입력해 주세요.")
      return false
    }

    guard isEmailValidated, validatedEmail == email else {
      showAlert("이메일 중복 확인을 먼저 완료해 주세요.")
      return false
    }

    guard !password.isEmpty else {
      showAlert("비밀번호를 입력해 주세요.")
      return false
    }

    guard password.count >= 8 else {
      showAlert("비밀번호는 8자 이상으로 입력해 주세요.")
      return false
    }

    guard password == passwordConfirmation else {
      showAlert("비밀번호 확인이 일치하지 않습니다.")
      return false
    }

    return true
  }

  mutating func validateProfileStep() -> Bool {
    guard !nick.trimmed.isEmpty else {
      showAlert("닉네임을 입력해 주세요.")
      return false
    }

    guard !name.trimmed.isEmpty else {
      showAlert("이름을 입력해 주세요.")
      return false
    }

    return true
  }

  var hashTags: [String]? {
    let values = hashTagsText
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }

    return values.isEmpty ? nil : values
  }

  mutating func showAlert(_ message: String) {
    alert = AlertState {
      TextState(message)
    }
  }
}

private extension String {
  var nilIfEmpty: String? {
    isEmpty ? nil : self
  }
}
