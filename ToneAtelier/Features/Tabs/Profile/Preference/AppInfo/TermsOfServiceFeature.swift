//
//  TermsOfServiceFeature.swift
//  ToneAtelier
//
//  Created by Claude on 5/7/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct TermsOfServiceFeature {
  @ObservableState
  struct State: Equatable {}

  enum Action: Sendable {}

  var body: some Reducer<State, Action> {
    EmptyReducer()
  }
}
