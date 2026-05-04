import SwiftUI

struct FeedEmptyStateView: View {
  let message: String
  let actionTitle: String?
  let action: (() -> Void)?

  var body: some View {
    VStack(spacing: 12) {
      Text(message)
        .pretendard(.body2)
        .foregroundStyle(AppTheme.gray75)
        .multilineTextAlignment(.center)

      if let actionTitle, let action {
        Button(action: action) {
          Text(actionTitle)
            .pretendard(.body2)
            .foregroundStyle(AppTheme.gray45)
            .padding(.horizontal, 18)
            .frame(height: 32)
            .background(AppTheme.blackTurquoise)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
      }
    }
    .frame(maxWidth: .infinity)
    .frame(height: 152)
  }
}
