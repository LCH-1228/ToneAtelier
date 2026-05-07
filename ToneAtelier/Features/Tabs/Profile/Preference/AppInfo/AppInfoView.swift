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

  var body: some View {
    ScrollView {
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
      .padding(.bottom, 32)
    }
    .scrollIndicators(.hidden)
    .background(AppTheme.background.ignoresSafeArea())
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(AppTheme.background, for: .navigationBar)
    .toolbarColorScheme(.dark, for: .navigationBar)
    .toolbar {
      PrincipalToolbarTitle("APP INFO")
    }
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
    .navigationDestination(
      isPresented: Binding(
        get: { store.termsOfService != nil },
        set: { isPresented in
          if !isPresented { store.send(.termsOfServiceDismissed) }
        }
      )
    ) {
      if let termsStore = store.scope(state: \.termsOfService, action: \.termsOfService) {
        TermsOfServiceView(store: termsStore)
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
