//
//  FeedPath.swift
//  ToneAtelier
//

import ComposableArchitecture
import Foundation

@Reducer(state: .equatable)
enum FeedPath {
  case detail(HomeDetailFeature)
  case userProfile(UserProfileFeature)
  case creatorStore(CreatorStoreFeature)
}
