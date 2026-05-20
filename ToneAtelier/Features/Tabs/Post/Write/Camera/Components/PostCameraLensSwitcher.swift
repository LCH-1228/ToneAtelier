//
//  PostCameraLensSwitcher.swift
//  ToneAtelier
//
//  Pencil: bueu0/lqD80 — viewfinder 위 floating lens preset 스위처.
//  AVCaptureDevice 의 가상 카메라 switch-over 결과로 결정된 preset 만 노출. iOS 순정 카메라 패턴.
//

import SwiftUI

struct PostCameraLensSwitcher: View {
  let presets: [PostCameraZoomPreset]
  let selected: PostCameraZoomPreset
  let onTap: (PostCameraZoomPreset) -> Void

  var body: some View {
    HStack(spacing: 6) {
      ForEach(presets, id: \.self) { preset in
        button(for: preset)
      }
    }
    .padding(.horizontal, 4)
    .frame(height: 40)
    .background(
      Color(red: 15.0 / 255, green: 18.0 / 255, blue: 19.0 / 255).opacity(0.87)
    )
    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .stroke(Color.white.opacity(0.2), lineWidth: 1)
    )
    .fixedSize()
    .opacity(presets.isEmpty ? 0 : 1)
    .allowsHitTesting(!presets.isEmpty)
  }

  private func button(for preset: PostCameraZoomPreset) -> some View {
    let isActive = preset == selected
    return Button {
      onTap(preset)
    } label: {
      Text(preset.displayLabel)
        .pretendard(.caption2Bold)
        .foregroundStyle(Color.white)
        .frame(width: 56, height: 32)
        .background(
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(isActive ? AnyShapeStyle(AppTheme.brightTurquoise) : AnyShapeStyle(Color.clear))
        )
        .opacity(isActive ? 1.0 : 0.88)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(preset.accessibilityLabel) \(isActive ? "선택됨" : "")")
  }
}
