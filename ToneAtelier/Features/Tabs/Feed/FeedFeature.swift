//
//  FeedFeature.swift
//  ToneAtelier
//
//  Created by Codex on 4/25/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct FeedFeature {
  @ObservableState
  struct State: Equatable {
    let category: HomeCategory

    var title: String {
      "Feed"
    }
  }

  enum Action: Sendable {
    case noop
  }

  var body: some Reducer<State, Action> {
    Reduce { _, _ in
      .none
    }
  }
}
