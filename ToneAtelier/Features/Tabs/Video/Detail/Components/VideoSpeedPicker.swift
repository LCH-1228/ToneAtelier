//
//  VideoSpeedPicker.swift
//  ToneAtelier
//
//  Created by Codex on 5/5/26.
//

import SwiftUI

struct VideoSpeedPicker: View {
  static let options: [Float] = [0.5, 0.75, 1.0, 1.5, 2.0]

  let selected: Float
  let onSelect: (Float) -> Void

  var body: some View {
    Menu {
      ForEach(Self.options, id: \.self) { value in
        Button {
          onSelect(value)
        } label: {
          if abs(value - selected) < 0.01 {
            Label(label(for: value), systemImage: "checkmark")
          } else {
            Text(label(for: value))
          }
        }
      }
    } label: {
      HStack(spacing: 4) {
        Text(label(for: selected))
          .pretendard(.captionBold)
          .foregroundStyle(AppTheme.gray30)
        Image(systemName: "chevron.down")
          .font(AppTheme.symbol(size: 10, weight: .bold))
          .foregroundStyle(AppTheme.gray30)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(AppTheme.deepTurquoise, in: Capsule())
      .contentShape(.rect)
    }
    .accessibilityLabel("재생속도 선택")
    .accessibilityIdentifier("video_detail_speed_picker")
  }

  private func label(for value: Float) -> String {
    String(format: "%.2gx", value)
  }
}
