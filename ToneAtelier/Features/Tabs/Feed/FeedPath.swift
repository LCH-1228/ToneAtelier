//
//  FeedPath.swift
//  ToneAtelier
//

import ComposableArchitecture
import Foundation

@Reducer(state: .equatable)
enum FeedPath {
  case detail(HomeDetailFeature)
}
