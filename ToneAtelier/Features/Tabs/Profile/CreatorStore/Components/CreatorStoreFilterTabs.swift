//
//  CreatorStoreFilterTabs.swift
//  ToneAtelier
//
//  Created by Codex on 5/1/26.
//

import SwiftUI

/// 작가 스토어 정렬 탭. Pencil `WYtVR` (Store Filter Tabs) 매핑.
/// 전체/인기/최신 capsule 형식. 클라이언트 사이드 정렬을 트리거한다.
struct CreatorStoreFilterTabs: View {
  let selected: CreatorStoreFilterTab
  let onSelect: (CreatorStoreFilterTab) -> Void

  var body: some View {
    HStack(spacing: 8) {
      ForEach(CreatorStoreFilterTab.allCases) { tab in
        let isSelected = tab == selected

        Button {
          onSelect(tab)
        } label: {
          Text(tab.title)
            .font(AppTheme.pretendard(size: 12, weight: .bold))
            .foregroundStyle(isSelected ? AppTheme.gray30 : AppTheme.gray60)
            .padding(.horizontal, 16)
            .frame(height: 28)
            .background(isSelected ? AppTheme.brightTurquoise : AppTheme.blackTurquoise)
            .overlay {
              Capsule()
                .stroke(AppTheme.deepTurquoise, lineWidth: isSelected ? 0 : 1)
            }
            .clipShape(Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(tab.title) 정렬")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
      }

      Spacer(minLength: 0)
    }
  }
}

#Preview {
  StatefulPreviewWrapper(CreatorStoreFilterTab.popular) { binding in
    CreatorStoreFilterTabs(selected: binding.wrappedValue) { tab in
      binding.wrappedValue = tab
    }
    .padding(20)
    .background(AppTheme.background)
    .preferredColorScheme(.dark)
  }
}

private struct StatefulPreviewWrapper<Value, Content: View>: View {
  @State private var value: Value
  let content: (Binding<Value>) -> Content

  init(_ initial: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
    self._value = State(wrappedValue: initial)
    self.content = content
  }

  var body: some View {
    content($value)
  }
}
