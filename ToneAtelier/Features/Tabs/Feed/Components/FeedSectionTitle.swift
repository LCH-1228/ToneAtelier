import SwiftUI

struct FeedSectionTitle: View {
  let title: String

  var body: some View {
    HStack {
      Text(title)
        .font(AppTheme.pretendard(size: 16, weight: .bold))
        .foregroundStyle(AppTheme.gray60)

      Spacer()
    }
    .padding(.horizontal, 20)
  }
}
