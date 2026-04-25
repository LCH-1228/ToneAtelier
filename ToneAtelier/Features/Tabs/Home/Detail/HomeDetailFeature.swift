//
//  HomeDetailFeature.swift
//  ToneAtelier
//
//  Created by Codex on 4/25/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct HomeDetailFeature {
  @ObservableState
  struct State: Equatable {
    let trend: HomeTrend

    var title: String {
      "Detail"
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
