//
//  BannerClient.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import ComposableArchitecture
import Foundation

struct BannerClient {
  var fetchMainBanners: @Sendable () async throws -> JSONValue
}

extension BannerClient: DependencyKey {
  static var liveValue: BannerClient {
    @Dependency(\.httpClient) var httpClient

    return BannerClient(
      fetchMainBanners: {
        try await httpClient.send(
          APIEndpoint<JSONValue>(router: BannerRouter.fetchMainBanners)
        )
      }
    )
  }

  static let testValue = BannerClient(
    fetchMainBanners: {
      throw APIError.transport("BannerClient.fetchMainBanners testValue")
    }
  )
}

extension DependencyValues {
  var bannerClient: BannerClient {
    get { self[BannerClient.self] }
    set { self[BannerClient.self] = newValue }
  }
}
