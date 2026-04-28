import SwiftUI

struct FeedNavigationHeader: View {
  let backAction: (() -> Void)?

  var body: some View {
    HStack {
      if let backAction {
        SharedIconButton(
          accessibilityLabel: "뒤로 가기",
          action: backAction
        ) {
          Image(systemName: "chevron.left")
            .font(.system(size: 22, weight: .medium))
            .foregroundStyle(HomeTheme.gray75)
        }
      } else {
        Color.clear
          .frame(width: 48, height: 48)
      }

      Spacer()

      Text("FEED")
        .font(HomeTheme.mulgyeol(size: 20, weight: .bold))
        .foregroundStyle(HomeTheme.gray60)

      Spacer()

      Color.clear
        .frame(width: 48, height: 48)
    }
    .frame(height: 56)
    .padding(.horizontal, 4)
  }
}
