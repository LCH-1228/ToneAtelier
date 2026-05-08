//
//  PostCameraFocusIndicator.swift
//  ToneAtelier
//
//  iOS 순정 카메라의 focus 사각형 + 우측 sun 트랙 패턴.
//  노란 사각형은 focus 위치 표시, sun 아이콘 vertical drag → exposure bias.
//

import SwiftUI

struct PostCameraFocusIndicator: View {
  let exposureBias: Float
  let onExposureBiasChange: (Float) -> Void

  static let squareSize: CGFloat = 80
  private static let sunColumnWidth: CGFloat = 28
  private static let pointsPerEV: CGFloat = 40

  @State private var dragStartBias: Float?

  var body: some View {
    HStack(spacing: 4) {
      Rectangle()
        .stroke(Color.yellow, lineWidth: 1)
        .frame(width: Self.squareSize, height: Self.squareSize)

      sunColumn
    }
    .compositingGroup()
  }

  private var sunColumn: some View {
    ZStack {
      Rectangle()
        .fill(Color.yellow.opacity(0.7))
        .frame(width: 1, height: Self.squareSize)

      Image(systemName: "sun.max.fill")
        .font(.system(size: 14, weight: .regular))
        .foregroundStyle(Color.yellow)
        .offset(y: -CGFloat(exposureBias) * 20)
    }
    .frame(width: Self.sunColumnWidth, height: Self.squareSize)
    .contentShape(Rectangle())
    .gesture(
      DragGesture(minimumDistance: 0)
        .onChanged { value in
          if dragStartBias == nil {
            dragStartBias = exposureBias
          }
          let start = dragStartBias ?? exposureBias
          let deltaEV = -Float(value.translation.height / Self.pointsPerEV)
          let next = max(-2, min(2, start + deltaEV))
          onExposureBiasChange(next)
        }
        .onEnded { _ in
          dragStartBias = nil
        }
    )
    .accessibilityLabel("노출 조절")
    .accessibilityValue("\(String(format: "%.1f", exposureBias)) EV")
  }
}
