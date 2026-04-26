import SwiftUI

struct FeedBlockLayout: View {
  let availableWidth: CGFloat
  let items: [FeedFilterItem]
  let isLoading: Bool
  let isLoadingNextPage: Bool
  let errorMessage: String?
  let nextPageErrorMessage: String?
  let canLoadNextPage: Bool
  let likingFilterIDs: Set<FeedFilterItem.ID>
  let itemAppearAction: (FeedFilterItem.ID) -> Void
  let likeAction: (FeedFilterItem.ID) -> Void
  let refreshAction: () -> Void
  let nextPageRetryAction: () -> Void

  var body: some View {
    Group {
      if items.isEmpty {
        FeedEmptyStateView(
          message: errorMessage ?? (isLoading ? "필터 피드를 불러오는 중입니다." : "표시할 필터가 없습니다."),
          actionTitle: errorMessage == nil ? nil : "다시 시도",
          action: errorMessage == nil ? nil : refreshAction
        )
        .padding(.horizontal, 20)
        .padding(.top, 16)
      } else {
        let masonryColumns = masonryColumnItems

        VStack(spacing: 16) {
          HStack(alignment: .top, spacing: FeedLayout.masonryColumnSpacing) {
            LazyVStack(spacing: 24) {
              ForEach(masonryColumns.left, id: \.element.id) { indexedItem in
                FeedBlockItemView(
                  item: indexedItem.element,
                  imageWidth: columnWidth,
                  imageHeight: imageHeight(for: indexedItem.offset),
                  isLikeRequestInFlight: likingFilterIDs.contains(indexedItem.element.id),
                  likeAction: likeAction
                )
                .frame(width: columnWidth)
                .onAppear {
                  itemAppearAction(indexedItem.element.id)
                }
              }
            }
            .frame(width: columnWidth)

            LazyVStack(spacing: 24) {
              ForEach(masonryColumns.right, id: \.element.id) { indexedItem in
                FeedBlockItemView(
                  item: indexedItem.element,
                  imageWidth: columnWidth,
                  imageHeight: imageHeight(for: indexedItem.offset),
                  isLikeRequestInFlight: likingFilterIDs.contains(indexedItem.element.id),
                  likeAction: likeAction
                )
                .frame(width: columnWidth)
                .onAppear {
                  itemAppearAction(indexedItem.element.id)
                }
              }
            }
            .frame(width: columnWidth)
          }
          .frame(maxWidth: .infinity, alignment: .center)

          FeedPaginationFooterView(
            isLoading: isLoadingNextPage,
            errorMessage: nextPageErrorMessage,
            canLoadNextPage: canLoadNextPage,
            retryAction: nextPageRetryAction
          )
        }
        .padding(.horizontal, FeedLayout.horizontalPadding)
        .padding(.top, 16)
      }
    }
  }

  private var columnWidth: CGFloat {
    max(
      0,
      (availableWidth - (FeedLayout.horizontalPadding * 2) - FeedLayout.masonryColumnSpacing) / 2
    )
  }

  private var masonryColumnItems: (
    left: [(offset: Int, element: FeedFilterItem)],
    right: [(offset: Int, element: FeedFilterItem)]
  ) {
    let layout = FeedMasonryColumnLayout.make(itemCount: items.count) { index in
      Double(itemHeight(for: index))
    }

    return (
      left: layout.leftIndexes.map { ($0, items[$0]) },
      right: layout.rightIndexes.map { ($0, items[$0]) }
    )
  }

  private func imageHeight(for index: Int) -> CGFloat {
    switch index % 4 {
    case 0: return 226
    case 1: return 128
    case 2: return 128
    default: return 210
    }
  }

  private func itemHeight(for index: Int) -> CGFloat {
    imageHeight(for: index) + 8 + 18 + 24
  }
}
