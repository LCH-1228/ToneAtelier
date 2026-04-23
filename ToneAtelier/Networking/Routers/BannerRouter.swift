//
//  BannerRouter.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import Foundation

enum BannerRouter: APIRouter {
  case fetchMainBanners

  var method: HTTPMethod {
    switch self {
    case .fetchMainBanners: return .get
    }
  }

  var path: String {
    switch self {
    case .fetchMainBanners: return APIInfo.Path.bannersMain
    }
  }

  var requiresAccessToken: Bool { true }
}
