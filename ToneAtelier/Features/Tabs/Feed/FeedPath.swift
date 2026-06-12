//
//  FeedPath.swift
//  ToneAtelier
//

import ComposableArchitecture
import Foundation

@Reducer
enum FeedPath {
  case detail(HomeDetailFeature)
  case userProfile(UserProfileFeature)
  case creatorStore(CreatorStoreFeature)
  case makeView(MakeFeature)
}

extension FeedPath.State: Equatable {}
