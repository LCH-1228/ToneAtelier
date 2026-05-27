//
//  AuthRouter.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import Foundation

enum AuthRouter: APIRouter {
  case refresh

  var method: HTTPMethod {
    switch self {
    case .refresh: return .get
    }
  }

  var path: String {
    switch self {
    case .refresh: return APIInfo.Path.authRefresh
    }
  }

  var requiresAccessToken: Bool {
    switch self {
    case .refresh: return true
    }
  }

  var requiresRefreshToken: Bool {
    switch self {
    case .refresh: return true
    }
  }

  var extractsTokensFromResponse: Bool {
    switch self {
    case .refresh: return true
    }
  }
}
