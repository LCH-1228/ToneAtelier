import SwiftUI

struct UserProfileFeaturedFilterCard: View {
  let filter: FeaturedFilter
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        CachedImageView(
          urlString: filter.thumbnailURL,
          placeholderIconName: AppAsset.HomeCategory.star
        )
        .frame(width: 76, height: 76)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

        VStack(alignment: .leading, spacing: 7) {
          Text(filter.name)
            .mulgyeol(.pageTitle)
            .foregroundStyle(AppTheme.gray30)

          Text(filter.meta)
            .pretendard(.captionMeta)
            .foregroundStyle(AppTheme.gray75)

          Text(filter.description)
            .pretendard(.captionMeta)
            .foregroundStyle(AppTheme.gray60)
            .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        Image(systemName: "chevron.right")
          .font(AppTheme.symbol(size: 16, weight: .medium))
          .foregroundStyle(AppTheme.gray60)
      }
      .padding(10)
      .frame(height: 96)
      .background(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(AppTheme.blackTurquoise)
      )
    }
    .buttonStyle(.plain)
  }
}

#Preview {
  UserProfileFeaturedFilterCard(filter: .placeholder, action: {})
    .padding(20)
    .background(AppTheme.background)
    .preferredColorScheme(.dark)
}
