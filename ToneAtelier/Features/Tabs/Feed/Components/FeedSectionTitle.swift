import SwiftUI

struct FeedSectionTitle: View {
  let title: String

  var body: some View {
    HStack {
      Text(title)
        .pretendard(.body1)
        .foregroundStyle(AppTheme.gray60)

      Spacer()
    }
    .padding(.horizontal, 20)
  }
}
