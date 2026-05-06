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
  case post
  case chat
  case profile

  var id: Self { self }

  func iconName(isSelected: Bool) -> String {
    switch self {
    case .home:
      return isSelected ? AppAsset.MainTab.homeFilled : AppAsset.MainTab.homeOutline
    case .feed:
      return isSelected ? AppAsset.MainTab.feedFilled : AppAsset.MainTab.feedOutline
    case .post:
      return isSelected ? AppAsset.MainTab.postFilled : AppAsset.MainTab.postOutline
    case .chat:
      return isSelected ? AppAsset.MainTab.searchFilled : AppAsset.MainTab.searchOutline
    case .profile:
      return isSelected ? AppAsset.MainTab.profileFilled : AppAsset.MainTab.profileOutline
    }
  }

  var accessibilityLabel: String {
    switch self {
    case .home: return "Home"
    case .feed: return "Feed"
    case .post: return "Post"
    case .chat: return "Chat"
    case .profile: return "Profile"
    }
  }
}
