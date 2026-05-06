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

  var body: some View {
    ScrollView {
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
      .padding(.bottom, 32)
    }
    .scrollIndicators(.hidden)
    .background(AppTheme.background.ignoresSafeArea())
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(AppTheme.background, for: .navigationBar)
    .toolbarColorScheme(.dark, for: .navigationBar)
    .toolbar {
      PrincipalToolbarTitle("OPEN SOURCE")
    }
    .task { await store.send(.task).finish() }
  }

  private var emptyView: some View {
    VStack(spacing: 6) {
      Text("라이선스 정보를 찾을 수 없습니다")
        .pretendard(.body2)
        .foregroundStyle(AppTheme.gray45)
      Text("자동 수집 도구 도입 후 표시됩니다.")
        .pretendard(.caption1)
        .foregroundStyle(AppTheme.gray60)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 40)
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
            .pretendard(.body3Bold)
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
          .pretendard(.captionMeta)
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
