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
          .tint(AppTheme.gray45)
          .frame(maxWidth: .infinity)
          .frame(height: 48)
      } else if let errorMessage {
        VStack(spacing: 10) {
          Text(errorMessage)
            .font(AppTheme.pretendard(size: 13, weight: .medium))
            .foregroundStyle(AppTheme.gray75)
            .multilineTextAlignment(.center)

          Button("다시 시도", action: retryAction)
            .font(AppTheme.pretendard(size: 13, weight: .bold))
            .foregroundStyle(AppTheme.gray45)
            .padding(.horizontal, 16)
            .frame(height: 30)
            .background(AppTheme.blackTurquoise)
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
