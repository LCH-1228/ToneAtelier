import SwiftUI

struct FeedSortButtonRow: View {
  let selectedOption: FeedSortOption
  let isDisabled: Bool
  let selectAction: (FeedSortOption) -> Void

  var body: some View {
    HStack(spacing: 8) {
      Spacer()

      ForEach(FeedSortOption.displayOptions, id: \.self) { option in
        Button {
          selectAction(option)
        } label: {
          FeedSortChip(
            title: option.title,
            isSelected: option == selectedOption
          )
        }
        .buttonStyle(.plain)
      }
    }
    .disabled(isDisabled)
    .opacity(isDisabled ? 0.55 : 1)
    .padding(.horizontal, 20)
  }
}
