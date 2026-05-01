//
//  CreatorStoreFeature.swift
//  ToneAtelier
//
//  Created by Codex on 5/1/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct CreatorStoreFeature {
  @ObservableState
  struct State: Equatable {
    let userID: String
    let isOwn: Bool
    /// ProfileFeature가 미리 알고 있는 닉네임이 있으면 헤더에 즉시 표시한다.
    /// hero 로드 후에는 hero.nickname을 우선 사용.
    var headerName: String?
    var hero: CreatorStoreHero?
    var items: [CreatorStoreItem] = []
    var selectedTab: CreatorStoreFilterTab = .popular
    var isLoading = false
    var hasLoaded = false
    var errorMessage: String?
    var detail: HomeDetailFeature.State?

    init(
      userID: String,
      isOwn: Bool,
      headerName: String? = nil
    ) {
      self.userID = userID
      self.isOwn = isOwn
      self.headerName = headerName
    }

    /// 정렬 탭 적용 결과. selectedTab에 따라 클라이언트 사이드 정렬을 수행한다.
    /// - popular: likeCount 내림차순
    /// - recent: createdAt 내림차순. createdAt이 없는 항목은 뒤로 밀어낸다.
    var sortedItems: [CreatorStoreItem] {
      switch selectedTab {
      case .popular:
        return items.sorted { $0.likeCount > $1.likeCount }
      case .recent:
        return items.sorted { lhs, rhs in
          switch (lhs.createdAt, rhs.createdAt) {
          case let (l?, r?): return l > r
          case (_?, nil): return true
          case (nil, _?): return false
          case (nil, nil): return false
          }
        }
      }
    }
  }

  enum Action: Sendable {
    case task
    case retryButtonTapped
    case tabSelected(CreatorStoreFilterTab)
    case rowTapped(CreatorStoreItem.ID)
    case createFilterButtonTapped
    case detail(HomeDetailFeature.Action)
    case detailDismissed
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case let .tabSelected(tab):
        state.selectedTab = tab
        return .none
      default:
        return .none
      }
    }
  }
}
