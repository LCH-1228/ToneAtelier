import SwiftUI

struct FeedListItemView: View {
  let item: FeedFilterItem
  let isLikeRequestInFlight: Bool
  let likeAction: (FeedFilterItem.ID) -> Void
  let selectAction: (FeedFilterItem.ID) -> Void

  var body: some View {
    HStack(spacing: 20) {
      ZStack(alignment: .bottomTrailing) {
        HomeRemoteImageView(
          urlString: item.imageURL,
          placeholderIconName: AppAsset.HomeCategory.star
        )
          .frame(width: 100, height: 120)
          .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
          .allowsHitTesting(false)

        Color.clear
          .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
          .onTapGesture {
            selectAction(item.id)
          }

        FeedLikeButton(
          item: item,
          iconSize: 18,
          showsCount: false,
          unlikedColor: HomeTheme.gray45,
          isRequestInFlight: isLikeRequestInFlight,
          action: likeAction
        )
      }
      .frame(width: 100, height: 120)

      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 8) {
          Text(item.title)
            .font(HomeTheme.mulgyeol(size: 20, weight: .bold))
            .foregroundStyle(HomeTheme.gray30)
            .lineLimit(1)

          Text(item.category)
            .font(HomeTheme.pretendard(size: 12, weight: .medium))
            .foregroundStyle(HomeTheme.gray60)
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(HomeTheme.blackTurquoise)
            .clipShape(Capsule())
        }

        Text(item.author)
          .font(HomeTheme.pretendard(size: 16, weight: .medium))
          .foregroundStyle(HomeTheme.gray75)

        Text(item.description)
          .font(HomeTheme.pretendard(size: 12, weight: .regular))
          .foregroundStyle(HomeTheme.gray60)
          .lineSpacing(6)
          .lineLimit(2)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .frame(height: 104)
      .contentShape(Rectangle())
      .onTapGesture {
        selectAction(item.id)
      }
    }
    .padding(.horizontal, 20)
  }
}
