import SwiftUI

struct FeedBlockItemView: View {
  let item: FeedFilterItem
  let imageWidth: CGFloat
  let imageHeight: CGFloat
  let isLikeRequestInFlight: Bool
  let likeAction: (FeedFilterItem.ID) -> Void
  let selectAction: (FeedFilterItem.ID) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      ZStack(alignment: .topLeading) {
        HomeRemoteImageView(
          urlString: item.imageURL,
          placeholderIconName: AppAsset.HomeCategory.star
        )
        .frame(width: imageWidth, height: imageHeight)
        .clipped()
        .allowsHitTesting(false)

        Text(item.title)
          .font(AppTheme.mulgyeol(size: 14))
          .foregroundStyle(AppTheme.gray30)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
          .padding(.leading, 12)
          .padding(.trailing, 12)
          .padding(.top, 8)
          .frame(maxWidth: .infinity, alignment: .leading)
          .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
          .allowsHitTesting(false)

        Color.clear
          .contentShape(Rectangle())
          .onTapGesture {
            selectAction(item.id)
          }
      }
      .frame(width: imageWidth, height: imageHeight)
      .overlay(alignment: .bottomTrailing) {
        FeedLikeButton(
          item: item,
          iconSize: 13,
          showsCount: true,
          unlikedColor: AppTheme.gray30,
          isRequestInFlight: isLikeRequestInFlight,
          action: likeAction
        )
        .padding(.trailing, 6)
        .padding(.bottom, 4)
      }
      .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

      Text(item.author)
        .font(AppTheme.pretendard(size: 12, weight: .medium))
        .foregroundStyle(Color(hex: 0x434347))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .padding(.leading, 12)
        .contentShape(Rectangle())
        .onTapGesture {
          selectAction(item.id)
        }
    }
    .frame(width: imageWidth, alignment: .leading)
  }
}
