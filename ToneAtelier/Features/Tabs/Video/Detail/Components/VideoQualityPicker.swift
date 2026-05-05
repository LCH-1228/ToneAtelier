//
//  VideoQualityPicker.swift
//  ToneAtelier
//
//  Created by Codex on 5/5/26.
//

import SwiftUI

struct VideoQualityPicker: View {
  let qualities: [StreamQualityDTO]
  let selected: String?

  let onSelect: (String?) -> Void

  var body: some View {
    Menu {
      Button {
        onSelect(nil)
      } label: {
        if selected == nil {
          Label("자동", systemImage: "checkmark")
        } else {
          Text("자동")
        }
      }
      ForEach(qualities, id: \.quality) { item in
        Button {
          onSelect(item.quality)
        } label: {
          if selected == item.quality {
            Label(item.quality, systemImage: "checkmark")
          } else {
            Text(item.quality)
          }
        }
      }
    } label: {
      HStack(spacing: 4) {
        Text(label)
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
    .accessibilityLabel("화질 선택")
    .accessibilityIdentifier("video_detail_quality_picker")
  }

  private var label: String {
    if let selected { return "고정 \(selected)" }
    let best = VideoMetaFormatter.bestQuality(qualities.map(\.quality)) ?? ""
    return best.isEmpty ? "자동" : "자동 (\(best))"
  }
}
