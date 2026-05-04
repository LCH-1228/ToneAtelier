//
//  AppInfoView.swift
//  ToneAtelier
//
//  Created by Codex on 5/2/26.
//

import ComposableArchitecture
import SwiftUI

struct AppInfoView: View {
  @Bindable var store: StoreOf<AppInfoFeature>
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        AppInfoHeader { dismiss() }

        VStack(alignment: .leading, spacing: 12) {
          AppInfoHeroCard(displayName: appDisplayName, version: appVersion, description: appDescription)

          AppInfoNavigationRow(title: "이용 약관") {
            store.send(.termsOfServiceTapped)
          }

          AppInfoNavigationRow(title: "오픈소스 라이선스") {
            store.send(.openSourceLicenseTapped)
          }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, MainTabBarView.Layout.contentInsetHeight + 32)
      }
    }
    .scrollIndicators(.hidden)
    .background(AppTheme.background.ignoresSafeArea())
    .toolbar(.hidden, for: .navigationBar)
    .alert($store.scope(state: \.alert, action: \.alert))
    .navigationDestination(
      isPresented: Binding(
        get: { store.licenseList != nil },
        set: { isPresented in
          if !isPresented { store.send(.licenseListDismissed) }
        }
      )
    ) {
      if let licenseStore = store.scope(state: \.licenseList, action: \.licenseList) {
        OpenSourceLicenseListView(store: licenseStore)
      }
    }
  }

  private var appDisplayName: String {
    let info = Bundle.main.infoDictionary
    if let display = info?["CFBundleDisplayName"] as? String, !display.isEmpty {
      return display
    }
    if let name = info?["CFBundleName"] as? String, !name.isEmpty {
      return name
    }
    return "ToneAtelier"
  }

  private var appVersion: String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
  }

  private var appDescription: String {
    "사진과 영상으로 일상을 기록하는 커뮤니티"
  }
}

// MARK: - Header

private struct AppInfoHeader: View {
  let onBack: () -> Void

  var body: some View {
    HStack(spacing: 0) {
      Button(action: onBack) {
        Image(systemName: "chevron.left")
          .font(AppTheme.symbol(size: 20, weight: .medium))
          .foregroundStyle(AppTheme.gray60)
          .frame(width: 48, height: 48)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("뒤로")

      Spacer(minLength: 0)

      Color.clear.frame(width: 48, height: 48)
    }
    .overlay {
      Text("APP INFO")
        .mulgyeol(.bodyNormal)
        .foregroundStyle(AppTheme.gray60)
        .accessibilityAddTraits(.isHeader)
    }
    .frame(height: 56)
    .padding(.horizontal, 20)
  }
}

// MARK: - Hero Card

private struct AppInfoHeroCard: View {
  let displayName: String
  let version: String
  let description: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(displayName)
        .mulgyeol(.pageTitle)
        .foregroundStyle(AppTheme.gray30)
      Text("버전 \(version) · \(description)")
        .pretendard(.captionBold)
        .foregroundStyle(AppTheme.gray75)
        .lineLimit(2)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(AppTheme.blackTurquoise)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(AppTheme.deepTurquoise, lineWidth: 1)
    )
  }
}

// MARK: - Navigation Row

private struct AppInfoNavigationRow: View {
  let title: String
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 12) {
        Text(title)
          .pretendard(.body3Bold)
          .foregroundStyle(AppTheme.gray30)
        Spacer(minLength: 0)
        Image(systemName: "chevron.right")
          .font(AppTheme.symbol(size: 18, weight: .medium))
          .foregroundStyle(AppTheme.gray75)
      }
      .padding(.horizontal, 12)
      .frame(height: 48)
      .background(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(AppTheme.blackTurquoise)
      )
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
  }
}

#Preview {
  NavigationStack {
    AppInfoView(
      store: Store(initialState: AppInfoFeature.State()) {
        AppInfoFeature()
      }
    )
  }
  .preferredColorScheme(.dark)
}
