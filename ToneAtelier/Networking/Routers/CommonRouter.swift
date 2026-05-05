//
//  CommonRouter.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import Foundation

enum CommonRouter: APIRouter {
  case fetchLogs
  case fetchPhoto(String)
  case fetchVideo(String)
  case fetchSubtitle(String)
  case webView(String)

  var method: HTTPMethod {
    switch self {
    case .fetchLogs, .fetchPhoto, .fetchVideo, .fetchSubtitle, .webView: return .get
    }
  }

  var path: String {
    switch self {
    case .fetchLogs: return APIInfo.Path.log
    case let .fetchPhoto(path):
      let normalizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
      return "\(APIInfo.Path.photo)/\(normalizedPath)"
    case let .fetchVideo(path):
      let normalizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
      return "\(APIInfo.Path.video)/\(normalizedPath)"
    case let .fetchSubtitle(path):
      let normalizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
      return "\(APIInfo.Path.subtitle)/\(normalizedPath)"
    case let .webView(path):
      return path.hasPrefix("/") ? path : "/\(path)"
    }
  }

  var requiresAccessToken: Bool {
    switch self {
      case .fetchLogs:
      return false
    case .fetchPhoto:
      return true
    case .fetchVideo:
      return true
    case .fetchSubtitle:
      return true
    case .webView:
      return false
    }
  }
}
