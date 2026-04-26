import SwiftUI

struct FeedModeHeader: View {
  let displayMode: FeedFeature.DisplayMode
  let modeAction: () -> Void

  var body: some View {
    HStack {
      Text("Filter Feed")
        .font(HomeTheme.pretendard(size: 16, weight: .bold))
        .foregroundStyle(HomeTheme.gray60)

      Spacer()

      Button(action: modeAction) {
        Text(displayMode.title)
          .font(HomeTheme.pretendard(size: 16, weight: .medium))
          .foregroundStyle(HomeTheme.gray75)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("피드 표시 모드 전환")
    }
    .padding(.horizontal, 20)
  }
}
