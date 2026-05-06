//
//  PreferenceView.swift
//  ToneAtelier
//
//  Created by Codex on 5/2/26.
//

import ComposableArchitecture
import SwiftUI
import UserNotifications

struct PreferenceView: View {
  @Bindable var store: StoreOf<PreferenceFeature>
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        VStack(alignment: .leading, spacing: 8) {
          PreferenceProfileCard(summary: store.summary) {
            store.send(.profileCardTapped)
          }

          PreferenceSectionTitle("알림")
          PreferenceRow(
            systemImage: "bell",
            title: "푸시 알림",
            variant: .toggle(
              // 시스템 권한은 앱이 직접 변경 불가 — toggle 값과 도메인 상태가 비선형 매핑이고
              // set 시점에 외부 효과(prompt/openSettings)가 필요해 Binding(get:set:)을 예외 허용.
              isOn: Binding(
                get: { store.pushAuthorizationStatus == .authorized },
                set: { _ in store.send(.pushNotificationToggleTapped) }
              )
            )
          )

          PreferenceSectionTitle("계정 및 구매")
          PreferenceRow(
            systemImage: "receipt",
            title: "구매 내역",
            variant: .chevron { store.send(.purchaseHistoryTapped) }
          )

          PreferenceSectionTitle("개인정보 및 앱")
          PreferenceRow(
            systemImage: "info.circle",
            title: "앱 버전",
            variant: .valueWithChevron(text: appVersion) { store.send(.appInfoTapped) }
          )
          PreferenceRow(
            systemImage: "rectangle.portrait.and.arrow.right",
            title: "로그아웃",
            variant: .value(
              text: store.summary.email,
              action: { store.send(.logoutTapped) }
            ),
            hasStroke: true
          )
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 32)
      }
    }
    .scrollIndicators(.hidden)
    .background(AppTheme.background.ignoresSafeArea())
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(AppTheme.background, for: .navigationBar)
    .toolbarColorScheme(.dark, for: .navigationBar)
    .toolbar {
      ToolbarItem(placement: .principal) {
        Text("PREFERENCE")
          .mulgyeol(.bodyNormal)
          .foregroundStyle(AppTheme.gray60)
      }
    }
    .task { await store.send(.task).finish() }
    .onChange(of: scenePhase) { _, newPhase in
      // 사용자가 시스템 설정 앱에서 권한을 변경한 뒤 복귀했을 때 toggle을 즉시 동기화.
      if newPhase == .active {
        store.send(.task)
      }
    }
    .navigationDestination(isPresented: presented(\.editProfile, dismiss: .editProfileDismissed)) {
      if let editStore = store.scope(state: \.editProfile, action: \.editProfile) {
        ProfileEditView(store: editStore)
      }
    }
    .navigationDestination(isPresented: presented(\.purchaseHistory, dismiss: .purchaseHistoryDismissed)) {
      if let purchaseStore = store.scope(state: \.purchaseHistory, action: \.purchaseHistory) {
        PurchaseHistoryView(store: purchaseStore)
      }
    }
    .navigationDestination(isPresented: presented(\.appInfo, dismiss: .appInfoDismissed)) {
      if let appInfoStore = store.scope(state: \.appInfo, action: \.appInfo) {
        AppInfoView(store: appInfoStore)
      }
    }
  }

  private func presented<Child>(
    _ keyPath: KeyPath<PreferenceFeature.State, Child?>,
    dismiss: PreferenceFeature.Action
  ) -> Binding<Bool> {
    Binding(
      get: { store.state[keyPath: keyPath] != nil },
      set: { isPresented in
        if !isPresented {
          store.send(dismiss)
        }
      }
    )
  }

  private var appVersion: String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
  }
}

// MARK: - Profile Card

private struct PreferenceProfileCard: View {
  let summary: ProfileSummary
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        avatar
        VStack(alignment: .leading, spacing: 2) {
          Text(summary.nickname)
            .mulgyeol(.smallTitle)
            .foregroundStyle(AppTheme.gray30)
          Text(subtitle)
            .pretendard(.caption2Bold)
            .foregroundStyle(AppTheme.gray75)
            .lineLimit(1)
        }
        Spacer(minLength: 0)
        Image(systemName: "chevron.right")
          .font(AppTheme.symbol(size: 18, weight: .medium))
          .foregroundStyle(AppTheme.gray75)
      }
      .padding(.horizontal, 10)
      .frame(height: 62)
      .background(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(AppTheme.blackTurquoise)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(AppTheme.deepTurquoise, lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
  }

  private var subtitle: String {
    let trimmed = summary.bio.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "알림 / 구매 / 앱 설정" : trimmed
  }

  private var avatar: some View {
    ZStack {
      Circle().fill(AppTheme.deepTurquoise)

      if let urlString = summary.avatarURL, !urlString.isEmpty {
        CachedImageView(urlString: urlString)
          .scaledToFill()
          .clipShape(Circle())
      } else {
        Image(AppAsset.Profile.avatar)
          .renderingMode(.template)
          .resizable()
          .scaledToFit()
          .padding(10)
          .foregroundStyle(AppTheme.gray60)
      }
    }
    .frame(width: 42, height: 42)
    .overlay {
      Circle().stroke(AppTheme.deepTurquoise, lineWidth: 2)
    }
  }
}

// MARK: - Section Title

private struct PreferenceSectionTitle: View {
  let title: String

  init(_ title: String) {
    self.title = title
  }

  var body: some View {
    Text(title)
      .pretendard(.body2)
      .foregroundStyle(AppTheme.gray60)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

// MARK: - Row

private struct PreferenceRow: View {
  enum Variant {
    case toggle(isOn: Binding<Bool>)
    case chevron(action: () -> Void)
    case value(text: String, action: (() -> Void)?)
    case valueWithChevron(text: String, action: () -> Void)
  }

  let systemImage: String
  let title: String
  let variant: Variant
  var hasStroke: Bool = false

  var body: some View {
    switch variant {
    case let .toggle(isOn):
      rowContent {
        Toggle("", isOn: isOn)
          .labelsHidden()
          .tint(AppTheme.brightTurquoise)
      }

    case let .chevron(action):
      Button(action: action) {
        rowContent {
          Image(systemName: "chevron.right")
            .font(AppTheme.symbol(size: 18, weight: .medium))
            .foregroundStyle(AppTheme.gray75)
        }
      }
      .buttonStyle(.plain)

    case let .value(text, action):
      if let action {
        Button(action: action) {
          rowContent {
            Text(text)
              .pretendard(.captionBold)
              .foregroundStyle(AppTheme.gray75)
              .lineLimit(1)
          }
        }
        .buttonStyle(.plain)
      } else {
        rowContent {
          Text(text)
            .pretendard(.captionBold)
            .foregroundStyle(AppTheme.gray75)
            .lineLimit(1)
        }
      }

    case let .valueWithChevron(text, action):
      Button(action: action) {
        rowContent {
          HStack(spacing: 6) {
            Text(text)
              .pretendard(.captionBold)
              .foregroundStyle(AppTheme.gray75)
              .lineLimit(1)
            Image(systemName: "chevron.right")
              .font(AppTheme.symbol(size: 18, weight: .medium))
              .foregroundStyle(AppTheme.gray75)
          }
        }
      }
      .buttonStyle(.plain)
    }
  }

  private func rowContent<Trailing: View>(@ViewBuilder trailing: () -> Trailing) -> some View {
    HStack(spacing: 12) {
      Image(systemName: systemImage)
        .font(AppTheme.symbol(size: 18, weight: .medium))
        .foregroundStyle(AppTheme.gray60)
        .frame(width: 20)

      Text(title)
        .pretendard(.body3Bold)
        .foregroundStyle(AppTheme.gray30)

      Spacer(minLength: 0)

      trailing()
    }
    .padding(.horizontal, 12)
    .frame(height: 38)
    .background(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(AppTheme.blackTurquoise)
    )
    .overlay {
      if hasStroke {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .stroke(AppTheme.deepTurquoise, lineWidth: 1)
      }
    }
    .contentShape(.rect)
  }
}

#Preview {
  NavigationStack {
    PreferenceView(
      store: Store(initialState: PreferenceFeature.State(summary: .placeholder)) {
        PreferenceFeature()
      }
    )
  }
  .preferredColorScheme(.dark)
}
