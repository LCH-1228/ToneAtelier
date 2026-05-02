//
//  MainTabBarView.swift
//  ToneAtelier
//
//  Created by Codex on 4/24/26.
//

import SwiftUI

struct MainTabBarView: View {
  enum Layout {
    static let height: CGFloat = 68
    static let topClearance: CGFloat = 12
    static let bottomPadding: CGFloat = 8

    static var contentInsetHeight: CGFloat {
      topClearance + height + bottomPadding
    }
  }

  @Binding var selectedTab: MainTab

  var body: some View {
    HStack(spacing: 32) {
      ForEach(MainTab.allCases) { item in
        Button {
          selectedTab = item
        } label: {
          let isSelected = item == selectedTab

          VStack(spacing: 4) {
            Capsule()
              .fill(isSelected ? AppTheme.gray15 : .clear)
              .frame(width: 24, height: 3)

            Image(item.iconName(isSelected: isSelected))
              .renderingMode(.template)
              .resizable()
              .scaledToFit()
              .frame(width: 24, height: 24)
              .foregroundStyle(isSelected ? AppTheme.gray15 : AppTheme.gray45)
              .frame(width: 32, height: 32)
          }
          .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.accessibilityLabel)
        .accessibilityAddTraits(item == selectedTab ? .isSelected : [])
      }
    }
    .padding(.horizontal, 31)
    .padding(.vertical, 8)
    .frame(height: Layout.height)
    .background(
      RoundedRectangle(cornerRadius: 34, style: .continuous)
        .fill(.ultraThinMaterial)
        .overlay {
          RoundedRectangle(cornerRadius: 34, style: .continuous)
            .stroke(AppTheme.tabBarBackground, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 4)
    )
    .padding(.horizontal, 20)
    .padding(.bottom, Layout.bottomPadding)
  }
}
