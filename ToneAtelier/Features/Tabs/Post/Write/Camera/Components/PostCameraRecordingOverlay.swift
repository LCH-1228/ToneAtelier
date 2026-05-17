//
//  PostCameraRecordingOverlay.swift
//  ToneAtelier
//

import SwiftUI

struct PostCameraRecordingOverlay: View {
  let duration: TimeInterval
  let onShutterTap: () -> Void

  @State private var isBlinking = false

  var body: some View {
    VStack {
      recordingHeader
        .padding(.top, 60)
      Spacer()
      stopShutter
        .padding(.bottom, 80)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .onAppear { isBlinking = true }
    .onDisappear { isBlinking = false }
  }

  private var recordingHeader: some View {
    HStack(spacing: 8) {
      Circle()
        .fill(Color(red: 0.95, green: 0.30, blue: 0.30))
        .frame(width: 10, height: 10)
        .opacity(isBlinking ? 0.3 : 1)
        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isBlinking)
      Text("REC \(Self.format(duration))")
        .pretendard(.captionBold)
        .foregroundStyle(AppTheme.gray30)
        .monospacedDigit()
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 8)
    .background(Color.black.opacity(0.5))
    .clipShape(Capsule())
  }

  private var stopShutter: some View {
    Button(action: onShutterTap) {
      ZStack {
        Circle()
          .stroke(AppTheme.gray30, lineWidth: 3.5)
          .frame(width: 64, height: 64)
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .fill(Color(red: 0.95, green: 0.30, blue: 0.30))
          .frame(width: 28, height: 28)
      }
      .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("녹화 중지")
  }

  private static func format(_ seconds: TimeInterval) -> String {
    let total = Int(seconds.rounded())
    let mm = total / 60
    let ss = total % 60
    return String(format: "%02d:%02d", mm, ss)
  }
}
