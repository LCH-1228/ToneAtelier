//
//  PostCameraBottomBar.swift
//  ToneAtelier
//
//  Pencil: pJjZX 의 bottom_bar(FKtW5) — 그라디언트 위 mode_strip(J21Kg) + shutter_row(W2oGD).
//  shutter_row: gallery_thumb(56×56) + shutter(64×64) + filter_btn(56×56, teal) — space_between.
//

import SwiftUI

struct PostCameraBottomBar: View {
  let cameraMode: PostCameraMode
  let isCapturing: Bool
  let isFilterActive: Bool
  let onModeTap: (PostCameraMode) -> Void
  let onGalleryTap: () -> Void
  let onShutterTap: () -> Void
  let onFilterTap: () -> Void

  var body: some View {
    VStack(spacing: 16) {
      modeStrip
      shutterRow
    }
    .padding(.top, 20)
    .padding(.bottom, 28)
    .frame(maxWidth: .infinity)
    .background(
      LinearGradient(
        colors: [
          PostCameraColors.glass.opacity(0),
          PostCameraColors.glass.opacity(0.93)
        ],
        startPoint: .top,
        endPoint: .bottom
      )
    )
  }

  private var modeStrip: some View {
    HStack(spacing: 22) {
      ForEach(PostCameraMode.allCases, id: \.self) { mode in
        Button(action: { onModeTap(mode) }) {
          Text(mode.displayLabel)
            .pretendard(.caption2Bold)
            .tracking(0.7)
            .foregroundStyle(mode == cameraMode ? AppTheme.brightTurquoise : AppTheme.gray60)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
      }
    }
    .frame(height: 16)
  }

  private var shutterRow: some View {
    HStack(spacing: 0) {
      galleryThumb
      Spacer(minLength: 0)
      shutterButton
      Spacer(minLength: 0)
      filterButton
    }
    .padding(.horizontal, 24)
    .frame(height: 74)
  }

  private var galleryThumb: some View {
    Button(action: onGalleryTap) {
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(AppTheme.blackTurquoise)
        .overlay(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(AppTheme.gray30.opacity(0.25), lineWidth: 1.5)
        )
        .overlay(
          Image(systemName: "photo.on.rectangle")
            .font(AppTheme.symbol(size: 18, weight: .regular))
            .foregroundStyle(AppTheme.gray30)
        )
        .frame(width: 56, height: 56)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("앨범에서 선택")
  }

  private var shutterButton: some View {
    Button(action: onShutterTap) {
      ZStack {
        Circle()
          .stroke(AppTheme.gray30, lineWidth: 3.5)
          .frame(width: 64, height: 64)
        shutterCore
        if isCapturing {
          ProgressView().tint(AppTheme.background)
        }
      }
      .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .disabled(isCapturing)
    .accessibilityLabel("촬영")
  }

  @ViewBuilder
  private var shutterCore: some View {
    switch cameraMode {
    case .photo:
      Circle()
        .fill(AppTheme.gray30)
        .frame(width: 52, height: 52)
    case .video:
      Circle()
        .fill(Color(red: 0.95, green: 0.30, blue: 0.30))
        .frame(width: 52, height: 52)
    }
  }

  private var filterButton: some View {
    Button(action: onFilterTap) {
      VStack(spacing: 1) {
        Image(systemName: "camera.aperture")
          .font(AppTheme.symbol(size: 18, weight: .regular))
        Text("FILTER")
          .pretendard(.caption2Bold)
          .tracking(0.5)
      }
      .foregroundStyle(isFilterActive ? AppTheme.background : AppTheme.gray30)
      .frame(width: 56, height: 56)
      .background(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(isFilterActive ? AnyShapeStyle(AppTheme.brightTurquoise) : AnyShapeStyle(Color.clear))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(
            isFilterActive ? AppTheme.brightTurquoise : AppTheme.gray30.opacity(0.3),
            lineWidth: 1.5
          )
      )
    }
    .buttonStyle(.plain)
    .accessibilityLabel("필터 시트 열기")
  }
}
