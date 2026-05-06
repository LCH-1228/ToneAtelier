//
//  HomePath.swift
//  ToneAtelier
//

import ComposableArchitecture
import Foundation

@Reducer(state: .equatable)
enum HomePath {
  case bannerWeb(HomeBannerWebFeature)
  case detail(HomeDetailFeature)
  case userProfile(UserProfileFeature)
  case creatorStore(CreatorStoreFeature)
  case videoList(VideoFeature)
}
