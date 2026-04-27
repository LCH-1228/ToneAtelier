//
//  MakeEditFeature.swift
//  ToneAtelier
//
//  Created by Codex on 4/28/26.
//

import ComposableArchitecture

@Reducer
struct MakeEditFeature {
  @ObservableState
  struct State: Equatable {}

  enum Action: Equatable, Sendable {}

  var body: some Reducer<State, Action> {
    EmptyReducer()
  }
}
