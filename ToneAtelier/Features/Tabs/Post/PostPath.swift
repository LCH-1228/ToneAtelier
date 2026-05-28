//
//  PostPath.swift
//  ToneAtelier
//

import ComposableArchitecture
import Foundation

@Reducer
enum PostPath {
  case detail(PostDetailFeature)
  case userPostsList(UserPostsFeature)
  case write(PostWriteFeature)
  case search(PostSearchFeature)
  case userProfile(UserProfileFeature)
}

extension PostPath.State: Equatable {}
