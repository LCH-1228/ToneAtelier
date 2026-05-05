//
//  PostPath.swift
//  ToneAtelier
//

import ComposableArchitecture
import Foundation

@Reducer(state: .equatable)
enum PostPath {
  case detail(PostDetailFeature)
  case userPostsList(UserPostsFeature)
  case write(PostWriteFeature)
  case search(PostSearchFeature)
}
