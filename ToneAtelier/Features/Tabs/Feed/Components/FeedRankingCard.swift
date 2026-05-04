import SwiftUI

struct FeedRankingCard: View {
  let item: FeedRankingItem
  let isFocused: Bool

  var body: some View {
    ZStack(alignment: .top) {
      RoundedRectangle(cornerRadius: 110, style: .continuous)
        .fill(AppTheme.blackTurquoise)
        .overlay {
          RoundedRectangle(cornerRadius: 110, style: .continuous)
            .stroke(isFocused ? AppTheme.blackTurquoise : AppTheme.deepTurquoise, lineWidth: 2)
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
          .pretendard(.caption1)
          .foregroundStyle(AppTheme.gray75)

        Text(item.title)
          .mulgyeol(.display)
          .foregroundStyle(AppTheme.gray30)
          .lineLimit(1)
          .minimumScaleFactor(0.8)

        Text(item.category)
          .pretendard(.body2)
          .foregroundStyle(AppTheme.gray75)
      }
      .frame(width: 141)
      .padding(.top, 236)

      Text("\(item.rank)")
        .mulgyeol(.display)
        .foregroundStyle(AppTheme.brightTurquoise)
        .frame(width: 44, height: 44)
        .background(AppTheme.blackTurquoise)
        .overlay {
          Circle()
            .stroke(AppTheme.deepTurquoise, lineWidth: 2)
        }
        .clipShape(Circle())
        .padding(.top, 353)
    }
  }
}
