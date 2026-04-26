import SwiftUI

struct FeedSectionTitle: View {
  let title: String

  var body: some View {
    HStack {
      Text(title)
        .font(HomeTheme.pretendard(size: 16, weight: .bold))
        .foregroundStyle(HomeTheme.gray60)

      Spacer()
    }
    .padding(.horizontal, 20)
  }
}
