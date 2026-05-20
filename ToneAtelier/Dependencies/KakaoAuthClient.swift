//
//  KakaoAuthClient.swift
//  ToneAtelier
//
//  Created by Codex on 4/23/26.
//

import ComposableArchitecture
import Foundation
import KakaoSDKAuth
import KakaoSDKUser

struct KakaoAuthClient {
  var login: @MainActor @Sendable () async throws -> String
}

extension KakaoAuthClient: DependencyKey {
  static let liveValue = KakaoAuthClient(
    login: {
      guard KakaoSDKConfiguration.isConfigured else {
        throw APIError.transport("Kakao Native App Key가 설정되지 않았습니다.")
      }

      return try await withCheckedThrowingContinuation { continuation in
        let completion: (OAuthToken?, Error?) -> Void = { token, error in
          if let error {
            continuation.resume(throwing: error)
            return
          }

          guard let accessToken = token?.accessToken, !accessToken.trimmed.isEmpty else {
            continuation.resume(throwing: APIError.transport("카카오 access token을 받지 못했습니다."))
            return
          }

          continuation.resume(returning: accessToken)
        }

        if UserApi.isKakaoTalkLoginAvailable() {
          UserApi.shared.loginWithKakaoTalk(completion: completion)
        } else {
          UserApi.shared.loginWithKakaoAccount(completion: completion)
        }
      }
    }
  )

  static let testValue = KakaoAuthClient(
    login: {
      throw APIError.transport("KakaoAuthClient.login testValue")
    }
  )
}

extension DependencyValues {
  var kakaoAuthClient: KakaoAuthClient {
    get { self[KakaoAuthClient.self] }
    set { self[KakaoAuthClient.self] = newValue }
  }
}
