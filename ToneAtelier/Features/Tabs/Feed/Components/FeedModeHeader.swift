import SwiftUI

struct FeedModeHeader: View {
  let displayMode: FeedFeature.DisplayMode
  let modeAction: () -> Void

  var body: some View {
    HStack {
      Text("Filter Feed")
        .pretendard(.body1)
        .foregroundStyle(AppTheme.gray60)

      Spacer()

      Button(action: modeAction) {
        Text(displayMode.title)
          .pretendard(.body1)
          .foregroundStyle(AppTheme.gray75)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("피드 표시 모드 전환")
    }
    .padding(.horizontal, 20)
  }
}
