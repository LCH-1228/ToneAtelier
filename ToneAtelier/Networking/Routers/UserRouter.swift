//
//  UserRouter.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import Foundation

enum UserRouter: APIRouter {
  case validateEmail(EmailValidationRequestDTO)
  case join(JoinRequestDTO)
  case login(EmailLoginRequestDTO)
  case loginKakao(KakaoLoginRequestDTO)
  case loginApple(AppleLoginRequestDTO)
  case logout
  case updateDeviceToken(DeviceTokenRequestDTO)
  case fetchOtherProfile(userID: String)
  case uploadProfileImage(UploadFile)
  case fetchMyProfile
  case updateMyProfile(ProfileRequestDTO)
  case fetchTodayAuthor
  case searchUsers(nick: String?)

  var method: HTTPMethod {
    switch self {
    case .validateEmail, .join, .login, .loginKakao, .loginApple, .logout, .uploadProfileImage:
      return .post
    case .updateDeviceToken, .updateMyProfile:
      return .put
    case .fetchOtherProfile, .fetchMyProfile, .fetchTodayAuthor, .searchUsers:
      return .get
    }
  }

  var path: String {
    switch self {
    case .validateEmail: return APIInfo.Path.usersValidationEmail
    case .join: return APIInfo.Path.usersJoin
    case .login: return APIInfo.Path.usersLogin
    case .loginKakao: return APIInfo.Path.usersLoginKakao
    case .loginApple: return APIInfo.Path.usersLoginApple
    case .logout: return APIInfo.Path.usersLogout
    case .updateDeviceToken: return APIInfo.Path.usersDeviceToken
    case let .fetchOtherProfile(userID): return "\(APIInfo.Path.users)/\(userID)\(APIInfo.Path.profile)"
    case .uploadProfileImage: return APIInfo.Path.usersProfileImage
    case .fetchMyProfile, .updateMyProfile: return APIInfo.Path.usersMeProfile
    case .fetchTodayAuthor: return APIInfo.Path.usersTodayAuthor
    case .searchUsers: return APIInfo.Path.usersSearch
    }
  }

  var queryItems: [URLQueryItem] {
    switch self {
    case let .searchUsers(nick):
      return [.optional(name: "nick", value: nick)].compactMap { $0 }
    default:
      return []
    }
  }

  var body: HTTPBody {
    get throws {
      switch self {
      case let .validateEmail(request): return try .jsonBody(request)
      case let .join(request): return try .jsonBody(request)
      case let .login(request): return try .jsonBody(request)
      case let .loginKakao(request): return try .jsonBody(request)
      case let .loginApple(request): return try .jsonBody(request)
      case let .updateDeviceToken(request): return try .jsonBody(request)
      case let .updateMyProfile(request): return try .jsonBody(request)
      case let .uploadProfileImage(file):
        return .multipart(
          MultipartFormData(parts: [
            .file(
              UploadFile(
                fieldName: "profile",
                fileName: file.fileName,
                mimeType: file.mimeType,
                data: file.data
              )
            )
          ])
        )
      default:
        return .none
      }
    }
  }

  var requiresAccessToken: Bool {
    switch self {
    case .logout,
         .updateDeviceToken,
         .fetchOtherProfile,
         .uploadProfileImage,
         .fetchMyProfile,
         .updateMyProfile,
         .fetchTodayAuthor,
         .searchUsers:
      return true
    default:
      return false
    }
  }
}
