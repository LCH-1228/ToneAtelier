import SwiftUI

struct FeedPaginationFooterView: View {
  let isLoading: Bool
  let errorMessage: String?
  let canLoadNextPage: Bool
  let retryAction: () -> Void

  var body: some View {
    Group {
      if isLoading {
        ProgressView()
          .tint(HomeTheme.gray45)
          .frame(maxWidth: .infinity)
          .frame(height: 48)
      } else if let errorMessage {
        VStack(spacing: 10) {
          Text(errorMessage)
            .font(HomeTheme.pretendard(size: 13, weight: .medium))
            .foregroundStyle(HomeTheme.gray75)
            .multilineTextAlignment(.center)

          Button("다시 시도", action: retryAction)
            .font(HomeTheme.pretendard(size: 13, weight: .bold))
            .foregroundStyle(HomeTheme.gray45)
            .padding(.horizontal, 16)
            .frame(height: 30)
            .background(HomeTheme.blackTurquoise)
            .clipShape(Capsule())
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
      } else if canLoadNextPage {
        Color.clear
          .frame(height: 40)
      }
    }
  }
}
