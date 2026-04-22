//
//  CommonRouter.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import Foundation

enum CommonRouter: APIRouter {
  case fetchLogs

  var method: HTTPMethod {
    switch self {
    case .fetchLogs: return .get
    }
  }

  var path: String {
    switch self {
    case .fetchLogs: return APIInfo.Path.log
    }
  }
}
