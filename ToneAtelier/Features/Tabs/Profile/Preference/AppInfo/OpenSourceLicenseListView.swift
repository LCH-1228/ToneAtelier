//
//  OpenSourceLicenseListView.swift
//  ToneAtelier
//
//  Created by Codex on 5/2/26.
//

import ComposableArchitecture
import SwiftUI

struct OpenSourceLicenseListView: View {
  @Bindable var store: StoreOf<OpenSourceLicenseListFeature>
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        OpenSourceLicenseHeader { dismiss() }

        VStack(alignment: .leading, spacing: 10) {
          if store.entries.isEmpty {
            emptyView
          } else {
            ForEach(store.entries) { entry in
              LicenseEntryCard(
                entry: entry,
                isExpanded: store.expandedIDs.contains(entry.id)
              ) {
                store.send(.toggleExpanded(id: entry.id))
              }
            }
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
    .task { await store.send(.task).finish() }
  }

  private var emptyView: some View {
    VStack(spacing: 6) {
      Text("라이선스 정보를 찾을 수 없습니다")
        .font(AppTheme.pretendard(size: 14, weight: .bold))
        .foregroundStyle(AppTheme.gray45)
      Text("자동 수집 도구 도입 후 표시됩니다.")
        .font(AppTheme.pretendard(size: 12, weight: .medium))
        .foregroundStyle(AppTheme.gray60)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 40)
  }
}

// MARK: - Header

private struct OpenSourceLicenseHeader: View {
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
      Text("OPEN SOURCE")
        .font(AppTheme.mulgyeol(size: 20))
        .foregroundStyle(AppTheme.gray60)
        .accessibilityAddTraits(.isHeader)
    }
    .frame(height: 56)
    .padding(.horizontal, 20)
  }
}

// MARK: - Entry Card

private struct LicenseEntryCard: View {
  let entry: LicenseEntry
  let isExpanded: Bool
  let onToggle: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Button(action: onToggle) {
        HStack(spacing: 12) {
          Text(entry.title)
            .font(AppTheme.pretendard(size: 13, weight: .bold))
            .foregroundStyle(AppTheme.gray30)
          Spacer(minLength: 0)
          Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .font(AppTheme.symbol(size: 14, weight: .medium))
            .foregroundStyle(AppTheme.gray75)
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .contentShape(.rect)
      }
      .buttonStyle(.plain)

      if isExpanded {
        Text(entry.body)
          .font(AppTheme.pretendard(size: 11, weight: .medium))
          .foregroundStyle(AppTheme.gray60)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 14)
          .padding(.bottom, 12)
          .textSelection(.enabled)
      }
    }
    .background(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(AppTheme.blackTurquoise)
    )
  }
}

#Preview {
  NavigationStack {
    OpenSourceLicenseListView(
      store: Store(initialState: OpenSourceLicenseListFeature.State()) {
        OpenSourceLicenseListFeature()
      }
    )
  }
  .preferredColorScheme(.dark)
}
