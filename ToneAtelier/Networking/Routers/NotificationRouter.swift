//
//  NotificationRouter.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import Foundation

enum NotificationRouter: APIRouter {
  case sendTestPush(PushNotificationRequest)

  var method: HTTPMethod {
    switch self {
    case .sendTestPush: return .post
    }
  }

  var path: String {
    switch self {
    case .sendTestPush: return APIInfo.Path.notificationsPush
    }
  }

  var body: HTTPBody {
    get throws {
      switch self {
      case let .sendTestPush(request): return try .jsonBody(request)
      }
    }
  }

  var requiresAccessToken: Bool { true }
}
