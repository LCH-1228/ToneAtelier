//
//  PostCameraActiveChip.swift
//  ToneAtelier
//
//  Pencil: hm6Hs (pJjZX 의 active filter chip).
//  swatch dot + 필터명 + 강도(%) 를 글래스 캡슐로 노출.
//

import SwiftUI

struct PostCameraActiveChip: View {
  let title: String
  let intensityPercent: Int
  let swatchColor: Color

  var body: some View {
    HStack(spacing: 8) {
      Circle()
        .fill(swatchColor)
        .frame(width: 8, height: 8)
      Text(title)
        .pretendard(.captionBold)
        .foregroundStyle(AppTheme.gray30)
      Text("\(intensityPercent)%")
        .pretendard(.captionBold)
        .foregroundStyle(AppTheme.brightTurquoise)
    }
    .padding(.horizontal, 14)
    .frame(height: 28)
    .background(PostCameraColors.glass)
    .clipShape(Capsule())
  }
}
