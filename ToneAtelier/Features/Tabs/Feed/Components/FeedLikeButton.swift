import SwiftUI

struct FeedLikeButton: View {
  let item: FeedFilterItem
  let iconSize: CGFloat
  let showsCount: Bool
  let unlikedColor: Color
  let isRequestInFlight: Bool
  let action: (FeedFilterItem.ID) -> Void

  var body: some View {
    Button {
      action(item.id)
    } label: {
      HStack(spacing: 2) {
        Image(item.isLiked ? AppAsset.Common.heartFilled : AppAsset.Common.heartOutline)
          .renderingMode(.template)
          .resizable()
          .scaledToFit()
          .frame(width: iconSize, height: iconSize)

        if showsCount {
          Text("\(item.likeCount)")
            .font(AppTheme.pretendard(size: 12, weight: .semibold))
        }
      }
      .foregroundStyle(item.isLiked ? AppTheme.gray15 : unlikedColor)
      .frame(width: 44, height: 44, alignment: .bottomTrailing)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(isRequestInFlight)
    .accessibilityLabel(item.isLiked ? "\(item.title) 좋아요 취소" : "\(item.title) 좋아요")
  }
}
