//
//  MainTab.swift
//  ToneAtelier
//
//  Created by Codex on 4/28/26.
//

import Foundation

enum MainTab: Int, CaseIterable, Identifiable, Equatable, Sendable {
  case home
  case feed
  case make
  case chat
  case profile

  var id: Self { self }

  func iconName(isSelected: Bool) -> String {
    switch self {
    case .home:
      return isSelected ? AppAsset.MainTab.homeFilled : AppAsset.MainTab.homeOutline
    case .feed:
      return isSelected ? AppAsset.MainTab.feedFilled : AppAsset.MainTab.feedOutline
    case .make:
      return isSelected ? AppAsset.MainTab.filterFilled : AppAsset.MainTab.filterOutline
    case .chat:
      return isSelected ? AppAsset.MainTab.searchFilled : AppAsset.MainTab.searchOutline
    case .profile:
      return isSelected ? AppAsset.MainTab.profileFilled : AppAsset.MainTab.profileOutline
    }
  }

  var accessibilityLabel: String {
    switch self {
    case .home: return "홈 탭"
    case .feed: return "피드 탭"
    case .make: return "필터 제작 탭"
    case .chat: return "채팅 탭"
    case .profile: return "프로필 탭"
    }
  }
}
