import SwiftUI

struct FeedSortChip: View {
  let title: String
  let isSelected: Bool

  var body: some View {
    Text(title)
      .font(HomeTheme.pretendard(size: 14, weight: isSelected ? .bold : .medium))
      .foregroundStyle(isSelected ? HomeTheme.gray45 : HomeTheme.gray75)
      .padding(.horizontal, 17)
      .frame(height: 28)
      .background(isSelected ? HomeTheme.brightTurquoise : HomeTheme.blackTurquoise)
      .overlay {
        if isSelected {
          Capsule()
            .stroke(HomeTheme.deepTurquoise, lineWidth: 1)
        }
      }
      .clipShape(Capsule())
  }
}
