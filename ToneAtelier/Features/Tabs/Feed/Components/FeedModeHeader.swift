import SwiftUI

struct FeedModeHeader: View {
  let displayMode: FeedFeature.DisplayMode
  let modeAction: () -> Void

  var body: some View {
    HStack {
      Text("Filter Feed")
        .font(AppTheme.pretendard(size: 16, weight: .bold))
        .foregroundStyle(AppTheme.gray60)

      Spacer()

      Button(action: modeAction) {
        Text(displayMode.title)
          .font(AppTheme.pretendard(size: 16, weight: .medium))
          .foregroundStyle(AppTheme.gray75)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("피드 표시 모드 전환")
    }
    .padding(.horizontal, 20)
  }
}
