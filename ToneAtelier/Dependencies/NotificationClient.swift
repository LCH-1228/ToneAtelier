//
//  NotificationClient.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import ComposableArchitecture
import Foundation

struct PushNotificationRequest: Encodable, Equatable, Sendable {
  let user_id: String
  let title: String
  let subtitle: String
  let body: String
}

struct NotificationClient {
  var sendTestPush: @Sendable (_ request: PushNotificationRequest) async throws -> EmptyResponse
}

extension NotificationClient: DependencyKey {
  static var liveValue: NotificationClient {
    @Dependency(\.httpClient) var httpClient

    return NotificationClient(
      sendTestPush: { request in
        try await httpClient.send(
          APIEndpoint<EmptyResponse>(router: NotificationRouter.sendTestPush(request))
        )
      }
    )
  }

  static let testValue = NotificationClient(
    sendTestPush: { _ in
      throw APIError.transport("NotificationClient.sendTestPush testValue")
    }
  )
}

extension DependencyValues {
  var notificationClient: NotificationClient {
    get { self[NotificationClient.self] }
    set { self[NotificationClient.self] = newValue }
  }
}
