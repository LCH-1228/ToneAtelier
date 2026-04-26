import SwiftUI

struct FeedRankingCarousel: View {
  let items: [FeedRankingItem]
  let selectAction: (FeedFilterItem.ID) -> Void

  var body: some View {
    GeometryReader { proxy in
      let centerX = proxy.size.width / 2
      let sideOffset = min(228, proxy.size.width * 0.58)

      ZStack(alignment: .topLeading) {
        if items.isEmpty {
          FeedEmptyStateView(
            message: "랭킹 필터를 불러오는 중입니다.",
            actionTitle: nil,
            action: nil
          )
          .padding(.horizontal, 20)
          .padding(.top, 108)
        } else {
          if let secondItem = items[safe: 1] {
            FeedRankingCard(item: secondItem, isFocused: false)
              .frame(width: 220, height: 397)
              .position(x: centerX - sideOffset, y: 275.5)
              .onTapGesture {
                selectAction(secondItem.id)
              }
          }

          if let thirdItem = items[safe: 2] {
            FeedRankingCard(item: thirdItem, isFocused: false)
              .frame(width: 220, height: 397)
              .position(x: centerX + sideOffset, y: 275.5)
              .onTapGesture {
                selectAction(thirdItem.id)
              }
          }

          if let firstItem = items.first {
            FeedRankingCard(item: firstItem, isFocused: true)
              .frame(width: 220, height: 397)
              .position(x: centerX, y: 198.5)
              .onTapGesture {
                selectAction(firstItem.id)
              }
          }
        }
      }
      .frame(width: proxy.size.width, height: proxy.size.height)
    }
    .clipped()
  }
}

private extension Array {
  subscript(safe index: Int) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}
