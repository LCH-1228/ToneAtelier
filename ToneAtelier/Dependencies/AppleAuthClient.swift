//
//  AppleAuthClient.swift
//  ToneAtelier
//
//  Created by Codex on 4/23/26.
//

import AuthenticationServices
import ComposableArchitecture
import Foundation
import UIKit

struct AppleAuthClient {
  var login: @MainActor @Sendable () async throws -> String
}

extension AppleAuthClient: DependencyKey {
  static let liveValue = AppleAuthClient(
    login: {
      let session = AppleAuthorizationSession()
      currentAppleAuthorizationSession = session
      defer { currentAppleAuthorizationSession = nil }

      return try await session.start()
    }
  )

  static let testValue = AppleAuthClient(
    login: {
      throw APIError.transport("AppleAuthClient.login testValue")
    }
  )
}

extension DependencyValues {
  var appleAuthClient: AppleAuthClient {
    get { self[AppleAuthClient.self] }
    set { self[AppleAuthClient.self] = newValue }
  }
}

@MainActor
private var currentAppleAuthorizationSession: AppleAuthorizationSession?

@MainActor
private final class AppleAuthorizationSession: NSObject {
  private var continuation: CheckedContinuation<String, Error>?
  private var controller: ASAuthorizationController?

  func start() async throws -> String {
    try await withCheckedThrowingContinuation { continuation in
      self.continuation = continuation

      let provider = ASAuthorizationAppleIDProvider()
      let request = provider.createRequest()
      request.requestedScopes = [.fullName, .email]

      let controller = ASAuthorizationController(authorizationRequests: [request])
      controller.delegate = self
      controller.presentationContextProvider = self
      self.controller = controller
      controller.performRequests()
    }
  }

  private func resume(returning idToken: String) {
    continuation?.resume(returning: idToken)
    continuation = nil
    controller = nil
  }

  private func resume(throwing error: Error) {
    continuation?.resume(throwing: error)
    continuation = nil
    controller = nil
  }
}

extension AppleAuthorizationSession: ASAuthorizationControllerDelegate {
  nonisolated func authorizationController(
    controller: ASAuthorizationController,
    didCompleteWithAuthorization authorization: ASAuthorization
  ) {
    Task { @MainActor in
      guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
        resume(throwing: APIError.transport("Apple ID 인증 정보를 받지 못했습니다."))
        return
      }

      guard
        let identityToken = credential.identityToken,
        let idToken = String(data: identityToken, encoding: .utf8),
        !idToken.trimmed.isEmpty
      else {
        resume(throwing: APIError.transport("Apple idToken을 받지 못했습니다."))
        return
      }

      resume(returning: idToken)
    }
  }

  nonisolated func authorizationController(
    controller: ASAuthorizationController,
    didCompleteWithError error: Error
  ) {
    Task { @MainActor in
      if let authorizationError = error as? ASAuthorizationError,
         authorizationError.code == .canceled {
        resume(throwing: APIError.transport("Apple 로그인이 취소되었습니다."))
        return
      }

      resume(throwing: error)
    }
  }
}

extension AppleAuthorizationSession: ASAuthorizationControllerPresentationContextProviding {
  nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    MainActor.assumeIsolated {
      let windowScenes = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }

      if let keyWindow = windowScenes
        .flatMap(\.windows)
        .first(where: \.isKeyWindow) {
        return keyWindow
      }

      if let windowScene = windowScenes.first {
        return ASPresentationAnchor(windowScene: windowScene)
      }

      preconditionFailure("Apple 로그인을 표시할 UIWindowScene을 찾지 못했습니다.")
    }
  }
}
