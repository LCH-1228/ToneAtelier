//
//  PostCameraPreviewSection.swift
//  ToneAtelier
//
//  Pencil: pJjZX 의 photo + 우측 warm tint(YvlOB) + compareDivider_2(vMGns) + section labels + compareHandle.
//  좌측 = 원본, 우측 = 필터 적용. 분할 비율 splitFraction(기본 0.633) 으로 우측 영역 크기 결정.
//  splitDragGesture 는 compareHandle 만 받음 — 나머지 영역은 tap 으로 focus/exposure 지정.
//

import SwiftUI

struct PostCameraPreviewSection: View {
  let session: PostCameraSession
  let filterValues: MakeFilterValues
  let splitFraction: Double
  let isFilterActive: Bool
  let onSplitFractionChange: (Double) -> Void
  /// (0...1, 0...1) 정규화된 preview-local 좌표. focus + exposure point 으로 사용.
  let onPreviewTap: (CGPoint) -> Void

  private static let previewSpace = "PostCameraPreviewSpace"

  var body: some View {
    GeometryReader { proxy in
      let size = proxy.size
      let clamped = max(0, min(1, splitFraction))
      let splitX = size.width * CGFloat(clamped)

      ZStack(alignment: .topLeading) {
        PostCameraPreviewView(
          session: session,
          filterValues: filterValues,
          splitFraction: splitFraction
        )
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
        .onTapGesture { location in
          let nx = max(0, min(1, location.x / max(size.width, 1)))
          let ny = max(0, min(1, location.y / max(size.height, 1)))
          onPreviewTap(CGPoint(x: nx, y: ny))
        }

        if isFilterActive {
          Rectangle()
            .fill(PostCameraColors.dividerLine)
            .frame(width: 2, height: size.height)
            .offset(x: splitX - 1)
            .allowsHitTesting(false)

          sectionLabels
            .frame(width: size.width, alignment: .topLeading)
            .allowsHitTesting(false)

          compareHandle
            .frame(width: 48, height: 48)
            .contentShape(Rectangle())
            .position(x: splitX, y: size.height * 0.5635)
            .gesture(splitDragGesture(width: size.width))
        }
      }
      .frame(width: size.width, height: size.height)
      .clipped()
      .coordinateSpace(name: Self.previewSpace)
    }
  }

  private var sectionLabels: some View {
    HStack {
      sectionPill(text: "원본", isAccent: false)
      Spacer()
      sectionPill(text: "필터", isAccent: true)
    }
    .padding(16)
  }

  private func sectionPill(text: String, isAccent: Bool) -> some View {
    Text(text)
      .pretendard(.caption2Bold)
      .foregroundStyle(AppTheme.gray30)
      .padding(.horizontal, 10)
      .frame(height: 22)
      .background(isAccent ? AnyShapeStyle(AppTheme.brightTurquoise) : AnyShapeStyle(PostCameraColors.glass))
      .clipShape(Capsule())
  }

  private var compareHandle: some View {
    ZStack {
      Circle()
        .fill(PostCameraColors.glassDark)
        .overlay(Circle().stroke(AppTheme.gray30.opacity(0.9), lineWidth: 2))
        .frame(width: 24, height: 24)
      Image(systemName: "play.fill")
        .font(.system(size: 8, weight: .black))
        .foregroundStyle(AppTheme.gray30)
    }
    .accessibilityLabel("분할 비교 핸들")
  }

  private func splitDragGesture(width: CGFloat) -> some Gesture {
    DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.previewSpace))
      .onChanged { value in
        guard isFilterActive else { return }
        let next = max(0, min(1, value.location.x / max(width, 1)))
        onSplitFractionChange(Double(next))
      }
  }
}
