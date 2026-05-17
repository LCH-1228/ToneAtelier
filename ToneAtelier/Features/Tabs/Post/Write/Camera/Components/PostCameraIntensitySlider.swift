//
//  PostCameraIntensitySlider.swift
//  ToneAtelier
//
//  시트와 viewfinder 오버레이가 공유하는 강도 슬라이더 — 시스템 Slider 사용으로 노브 렌더링이 안전.
//  외부 padding/배경은 호출 측에서 추가.
//

import SwiftUI

struct PostCameraIntensitySlider: View {
  let filterTitle: String
  let intensity: Double
  let onChange: (Double) -> Void

  private var percent: Int {
    Int((intensity * 100).rounded())
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 0) {
        Text("\(filterTitle) 강도")
          .pretendard(.caption2Bold)
          .foregroundStyle(Color.white.opacity(0.69))
        Spacer(minLength: 0)
        Text("\(percent)%")
          .pretendard(.caption2Bold)
          .foregroundStyle(AppTheme.brightTurquoise)
      }
      .frame(height: 14)

      Slider(
        value: Binding(
          get: { intensity },
          set: { onChange($0) }
        ),
        in: 0 ... 1
      )
      .tint(AppTheme.brightTurquoise)
    }
  }
}
