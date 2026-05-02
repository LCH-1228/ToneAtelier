//
//  UserClient.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import ComposableArchitecture
import Foundation

struct UserClient {
  var validateEmail: @Sendable (_ request: EmailValidationRequestDTO) async throws -> MessageResponse
  var join: @Sendable (_ request: JoinRequestDTO) async throws -> AuthenticatedUserResponse
  var login: @Sendable (_ request: EmailLoginRequestDTO) async throws -> AuthenticatedUserResponse
  var loginKakao: @Sendable (_ request: KakaoLoginRequestDTO) async throws -> AuthenticatedUserResponse
  var loginApple: @Sendable (_ request: AppleLoginRequestDTO) async throws -> AuthenticatedUserResponse
  var logout: @Sendable () async throws -> EmptyResponse
  var updateDeviceToken: @Sendable (_ request: DeviceTokenRequestDTO) async throws -> EmptyResponse
  var fetchOtherProfile: @Sendable (_ userID: String) async throws -> UserInfoResponseDTO
  var uploadProfileImage: @Sendable (_ file: UploadFile) async throws -> ProfileImageUploadResponse
  var fetchMyProfile: @Sendable () async throws -> MyInfoResponseDTO
  var updateMyProfile: @Sendable (_ request: ProfileRequestDTO) async throws -> MyInfoResponseDTO
  var fetchTodayAuthor: @Sendable () async throws -> TodayAuthorResponseDTO
  var searchUsers: @Sendable (_ nick: String?) async throws -> UserInfoListResponseDTO
}

extension UserClient: DependencyKey {
  static var liveValue: UserClient {
    @Dependency(\.httpClient) var httpClient

    return UserClient(
      validateEmail: { request in
        try await httpClient.send(
          APIEndpoint<MessageResponse>(router: UserRouter.validateEmail(request))
        )
      },
      join: { request in
        try await httpClient.send(
          APIEndpoint<AuthenticatedUserResponse>(router: UserRouter.join(request))
        )
      },
      login: { request in
        try await httpClient.send(
          APIEndpoint<AuthenticatedUserResponse>(router: UserRouter.login(request))
        )
      },
      loginKakao: { request in
        try await httpClient.send(
          APIEndpoint<AuthenticatedUserResponse>(router: UserRouter.loginKakao(request))
        )
      },
      loginApple: { request in
        try await httpClient.send(
          APIEndpoint<AuthenticatedUserResponse>(router: UserRouter.loginApple(request))
        )
      },
      logout: {
        try await httpClient.send(
          APIEndpoint<EmptyResponse>(router: UserRouter.logout)
        )
      },
      updateDeviceToken: { request in
        try await httpClient.send(
          APIEndpoint<EmptyResponse>(router: UserRouter.updateDeviceToken(request))
        )
      },
      fetchOtherProfile: { userID in
        try await httpClient.send(
          APIEndpoint<UserInfoResponseDTO>(router: UserRouter.fetchOtherProfile(userID: userID))
        )
      },
      uploadProfileImage: { file in
        try await httpClient.send(
          APIEndpoint<ProfileImageUploadResponse>(router: UserRouter.uploadProfileImage(file))
        )
      },
      fetchMyProfile: {
        try await httpClient.send(
          APIEndpoint<MyInfoResponseDTO>(router: UserRouter.fetchMyProfile)
        )
      },
      updateMyProfile: { request in
        try await httpClient.send(
          APIEndpoint<MyInfoResponseDTO>(router: UserRouter.updateMyProfile(request))
        )
      },
      fetchTodayAuthor: {
        try await httpClient.send(
          APIEndpoint<TodayAuthorResponseDTO>(router: UserRouter.fetchTodayAuthor)
        )
      },
      searchUsers: { nick in
        try await httpClient.send(
          APIEndpoint<UserInfoListResponseDTO>(router: UserRouter.searchUsers(nick: nick))
        )
      }
    )
  }

  static let testValue = UserClient(
    validateEmail: { _ in throw APIError.transport("UserClient.validateEmail testValue") },
    join: { _ in throw APIError.transport("UserClient.join testValue") },
    login: { _ in throw APIError.transport("UserClient.login testValue") },
    loginKakao: { _ in throw APIError.transport("UserClient.loginKakao testValue") },
    loginApple: { _ in throw APIError.transport("UserClient.loginApple testValue") },
    logout: { throw APIError.transport("UserClient.logout testValue") },
    updateDeviceToken: { _ in throw APIError.transport("UserClient.updateDeviceToken testValue") },
    fetchOtherProfile: { _ in throw APIError.transport("UserClient.fetchOtherProfile testValue") },
    uploadProfileImage: { _ in throw APIError.transport("UserClient.uploadProfileImage testValue") },
    fetchMyProfile: { throw APIError.transport("UserClient.fetchMyProfile testValue") },
    updateMyProfile: { _ in throw APIError.transport("UserClient.updateMyProfile testValue") },
    fetchTodayAuthor: { throw APIError.transport("UserClient.fetchTodayAuthor testValue") },
    searchUsers: { _ in throw APIError.transport("UserClient.searchUsers testValue") }
  )
}

extension DependencyValues {
  var userClient: UserClient {
    get { self[UserClient.self] }
    set { self[UserClient.self] = newValue }
  }
}
