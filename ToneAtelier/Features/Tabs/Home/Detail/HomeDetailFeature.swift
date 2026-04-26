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
    let id: String
    let title: String
    let summary: String?
    let likeCount: Int?

    init(
      id: String,
      title: String,
      summary: String?,
      likeCount: Int?
    ) {
      self.id = id
      self.title = title
      self.summary = summary
      self.likeCount = likeCount
    }

    init(trend: HomeTrend) {
      self.init(
        id: trend.id,
        title: trend.title,
        summary: nil,
        likeCount: trend.likeCount
      )
    }

    init(featuredFilter: HomeFeaturedFilter) {
      self.init(
        id: featuredFilter.id,
        title: featuredFilter.title,
        summary: featuredFilter.summary,
        likeCount: nil
      )
    }

    var navigationTitle: String {
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
