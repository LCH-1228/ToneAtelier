import SwiftUI

struct FeedSortButtonRow: View {
  var body: some View {
    HStack(spacing: 8) {
      Spacer()

      FeedSortChip(title: "인기순", isSelected: true)
      FeedSortChip(title: "구매순", isSelected: false)
      FeedSortChip(title: "최신순", isSelected: false)
    }
    .padding(.horizontal, 20)
  }
}
