import SwiftUI

struct FeedListItemView: View {
  let item: FeedFilterItem
  let isLikeRequestInFlight: Bool
  let likeAction: (FeedFilterItem.ID) -> Void
  let selectAction: (FeedFilterItem.ID) -> Void
  var showsLikeButton: Bool = true

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

        if showsLikeButton {
          FeedLikeButton(
            item: item,
            iconSize: 18,
            showsCount: false,
            unlikedColor: AppTheme.gray45,
            isRequestInFlight: isLikeRequestInFlight,
            action: likeAction
          )
        }
      }
      .frame(width: 100, height: 120)

      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 8) {
          Text(item.title)
            .font(AppTheme.mulgyeol(size: 20, weight: .bold))
            .foregroundStyle(AppTheme.gray30)
            .lineLimit(1)

          Text(item.category)
            .font(AppTheme.pretendard(size: 12, weight: .medium))
            .foregroundStyle(AppTheme.gray60)
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(AppTheme.blackTurquoise)
            .clipShape(Capsule())
        }

        // TODO: 작가 이름 옆에 "작가 필터 보기" 버튼을 추가하고, 해당 버튼 탭 시 CreatorStore 진입을 후속 브랜치에서 연결.
        Text(item.author)
          .font(AppTheme.pretendard(size: 16, weight: .medium))
          .foregroundStyle(AppTheme.gray75)

        Text(item.description)
          .font(AppTheme.pretendard(size: 12, weight: .regular))
          .foregroundStyle(AppTheme.gray60)
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
