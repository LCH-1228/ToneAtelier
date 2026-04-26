//
//  MainTabBarView.swift
//  ToneAtelier
//
//  Created by Codex on 4/24/26.
//

import SwiftUI

struct MainTabBarView: View {
  @Binding var selectedTab: Int

  var body: some View {
    HStack(spacing: 32) {
      ForEach(MainTabItem.allCases) { item in
        Button {
          selectedTab = item.rawValue
        } label: {
          VStack(spacing: 4) {
            Capsule()
              .fill(item.isSelected(selectedTab) ? HomeTheme.gray15 : .clear)
              .frame(width: 24, height: 3)

            Image(item.iconName(isSelected: item.isSelected(selectedTab)))
              .renderingMode(.template)
              .resizable()
              .scaledToFit()
              .frame(width: 24, height: 24)
              .foregroundStyle(item.isSelected(selectedTab) ? HomeTheme.gray15 : HomeTheme.gray45)
              .frame(width: 32, height: 32)
          }
          .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.accessibilityLabel)
      }
    }
    .padding(.horizontal, 31)
    .padding(.vertical, 8)
    .frame(height: 68)
    .background(
      RoundedRectangle(cornerRadius: 34, style: .continuous)
        .fill(.ultraThinMaterial)
        .overlay {
          RoundedRectangle(cornerRadius: 34, style: .continuous)
            .stroke(HomeTheme.tabBarBackground, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 4)
    )
    .padding(.horizontal, 20)
    .padding(.bottom, 8)
  }
}

private enum MainTabItem: Int, CaseIterable, Identifiable {
  case home
  case feed
  case video
  case chat
  case profile

  var id: Int { rawValue }

  func isSelected(_ selectedTab: Int) -> Bool {
    rawValue == selectedTab
  }

  func iconName(isSelected: Bool) -> String {
    switch self {
    case .home:
      return isSelected ? AppAsset.MainTab.homeFilled : AppAsset.MainTab.homeOutline
    case .feed:
      return isSelected ? AppAsset.MainTab.feedFilled : AppAsset.MainTab.feedOutline
    case .video:
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
    case .video: return "비디오 탭"
    case .chat: return "채팅 탭"
    case .profile: return "마이 탭"
    }
  }
}
