import SwiftUI

struct FeedSortChip: View {
  let title: String
  let isSelected: Bool

  var body: some View {
    SharedSelectableChipLabel(title: title, isSelected: isSelected)
  }
}
