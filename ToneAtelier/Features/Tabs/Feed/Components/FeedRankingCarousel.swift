import SwiftUI

struct FeedRankingCarousel: View {
  let items: [FeedRankingItem]
  let focusedID: FeedRankingItem.ID?
  let selectAction: (FeedRankingItem.ID) -> Void
  let focusAction: (FeedRankingItem.ID?) -> Void

  private let cardWidth: CGFloat = 220
  private let cardHeight: CGFloat = 397
  private let itemHeight: CGFloat = 474
  private let itemSpacing: CGFloat = 8
  private let sideVerticalOffset: CGFloat = 77

  var body: some View {
    GeometryReader { proxy in
      if items.isEmpty {
        FeedEmptyStateView(
          message: "랭킹 필터를 불러오는 중입니다.",
          actionTitle: nil,
          action: nil
        )
        .padding(.horizontal, 20)
        .padding(.top, 108)
      } else {
        let sideInset = max(0, (proxy.size.width - cardWidth) / 2)

        ScrollView(.horizontal, showsIndicators: false) {
          LazyHStack(spacing: itemSpacing) {
            ForEach(items) { item in
              Button {
                selectAction(item.id)
              } label: {
                FeedRankingCard(
                  item: item,
                  isFocused: item.id == focusedID
                )
                .frame(width: cardWidth, height: cardHeight)
                .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                  content
                    .offset(y: min(1, abs(phase.value)) * sideVerticalOffset)
                }
              }
              .buttonStyle(.plain)
              .frame(width: cardWidth, height: itemHeight, alignment: .top)
              .id(item.id)
            }
          }
          .scrollTargetLayout()
        }
        .contentMargins(.horizontal, sideInset, for: .scrollContent)
        .scrollPosition(id: scrollPosition)
        .scrollTargetBehavior(.viewAligned)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("상위 랭킹")
        .accessibilityValue(accessibilityValue)
      }
    }
    .clipped()
  }

  private var scrollPosition: Binding<FeedRankingItem.ID?> {
    Binding(
      get: { focusedID },
      set: { id in
        focusAction(id)
      }
    )
  }

  private var accessibilityValue: String {
    guard let focusedID,
          let item = items.first(where: { $0.id == focusedID }) else {
      return "랭킹 없음"
    }

    return "\(item.rank)위, \(item.title)"
  }
}
