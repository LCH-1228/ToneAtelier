import SwiftUI

struct FeedRankingCard: View {
  let item: FeedRankingItem
  let isFocused: Bool

  var body: some View {
    ZStack(alignment: .top) {
      RoundedRectangle(cornerRadius: 110, style: .continuous)
        .fill(HomeTheme.blackTurquoise)
        .overlay {
          RoundedRectangle(cornerRadius: 110, style: .continuous)
            .stroke(isFocused ? HomeTheme.blackTurquoise : HomeTheme.deepTurquoise, lineWidth: 2)
        }
        .frame(width: 220, height: 380)

      HomeRemoteImageView(
        urlString: item.imageURL,
        placeholderIconName: AppAsset.HomeCategory.star
      )
      .frame(width: 204, height: 204)
      .clipShape(Circle())
      .padding(.top, 8)

      VStack(spacing: 8) {
        Text(item.author)
          .font(HomeTheme.pretendard(size: 12, weight: .semibold))
          .foregroundStyle(HomeTheme.gray75)

        Text(item.title)
          .font(HomeTheme.mulgyeol(size: 32, weight: .bold))
          .foregroundStyle(HomeTheme.gray30)
          .lineLimit(1)
          .minimumScaleFactor(0.8)

        Text(item.category)
          .font(HomeTheme.pretendard(size: 14, weight: .bold))
          .foregroundStyle(HomeTheme.gray75)
      }
      .frame(width: 141)
      .padding(.top, 236)

      Text("\(item.rank)")
        .font(HomeTheme.mulgyeol(size: 32, weight: .bold))
        .foregroundStyle(HomeTheme.brightTurquoise)
        .frame(width: 44, height: 44)
        .background(HomeTheme.blackTurquoise)
        .overlay {
          Circle()
            .stroke(HomeTheme.deepTurquoise, lineWidth: 2)
        }
        .clipShape(Circle())
        .padding(.top, 353)
    }
  }
}
