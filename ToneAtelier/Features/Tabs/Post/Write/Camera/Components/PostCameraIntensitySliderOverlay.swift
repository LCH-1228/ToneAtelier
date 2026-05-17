//
//  PostCameraIntensitySliderOverlay.swift
//  ToneAtelier
//
//  Pencil: z4TEF/B5sxu — 필터 적용 시 viewfinder 위 floating 강도 슬라이더.
//  공용 PostCameraIntensitySlider 를 시트와 동일하게 재사용. 외곽에 contentShape + zIndex 로
//  PreviewSection 의 splitDragGesture 보다 hit-test/UI 우선 보장.
//

import SwiftUI

struct PostCameraIntensitySliderOverlay: View {
  let filterTitle: String
  let intensity: Double
  let onChange: (Double) -> Void

  var body: some View {
    PostCameraIntensitySlider(
      filterTitle: filterTitle,
      intensity: intensity,
      onChange: onChange
    )
    .padding(.top, 10)
    .padding(.horizontal, 18)
    .padding(.bottom, 6)
    .frame(maxWidth: .infinity)
    .contentShape(Rectangle())
    // 슬라이더 영역에 떨어진 드래그가 PreviewSection 의 splitDragGesture 로 새지 않도록 흡수.
    // 시스템 Slider 자체 제스처는 자식 우선이라 정상 동작.
    .simultaneousGesture(DragGesture(minimumDistance: 0))
    .zIndex(2)
  }
}
