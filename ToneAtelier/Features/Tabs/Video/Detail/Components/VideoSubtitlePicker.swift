//
//  VideoSubtitlePicker.swift
//  ToneAtelier
//
//  Created by Codex on 5/5/26.
//

import SwiftUI

struct VideoSubtitlePicker: View {
  let subtitles: [StreamSubtitleDTO]
  let selected: StreamSubtitleDTO?
  let onSelect: (StreamSubtitleDTO?) -> Void

  var body: some View {
    Menu {
      Button("자막 끄기") {
        onSelect(nil)
      }
      ForEach(subtitles, id: \.language) { subtitle in
        Button {
          onSelect(subtitle)
        } label: {
          if selected?.language == subtitle.language {
            Label(subtitle.name, systemImage: "checkmark")
          } else {
            Text(subtitle.name)
          }
        }
      }
    } label: {
      Image(systemName: "captions.bubble")
        .font(AppTheme.symbol(size: 18, weight: .regular))
        .foregroundStyle(selected == nil ? AppTheme.gray60 : AppTheme.gray30)
        .frame(width: 32, height: 32)
        .contentShape(.rect)
    }
    .accessibilityLabel("자막 선택")
    .accessibilityIdentifier("video_detail_subtitle_picker")
  }
}
