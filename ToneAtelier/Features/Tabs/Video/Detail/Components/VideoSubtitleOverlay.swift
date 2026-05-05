//
//  VideoSubtitleOverlay.swift
//  ToneAtelier
//
//  Created by Codex on 5/5/26.
//

import SwiftUI

// hit-test 받지 않아 영상 탭 → 컨트롤 토글에 영향 없음.
struct VideoSubtitleOverlay: View {
  let text: String?

  var body: some View {
    VStack(spacing: 0) {
      Spacer(minLength: 0)
      if let text, !text.isEmpty {
        Text(text)
          .pretendard(.body3Bold)
          .foregroundStyle(.white)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
          .padding(.horizontal, 16)
          .padding(.bottom, 60)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .allowsHitTesting(false)
    .accessibilityIdentifier("video_subtitle_overlay")
  }
}
