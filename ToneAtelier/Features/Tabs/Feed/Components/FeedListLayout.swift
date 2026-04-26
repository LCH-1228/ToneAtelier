import SwiftUI

struct FeedListLayout: View {
  let items: [FeedFilterItem]
  let isLoading: Bool
  let isLoadingNextPage: Bool
  let errorMessage: String?
  let nextPageErrorMessage: String?
  let canLoadNextPage: Bool
  let likingFilterIDs: Set<FeedFilterItem.ID>
  let itemAppearAction: (FeedFilterItem.ID) -> Void
  let likeAction: (FeedFilterItem.ID) -> Void
  let selectAction: (FeedFilterItem.ID) -> Void
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
        LazyVStack(spacing: 0) {
          ForEach(items) { item in
            FeedListItemView(
              item: item,
              isLikeRequestInFlight: likingFilterIDs.contains(item.id),
              likeAction: likeAction,
              selectAction: selectAction
            )
            .frame(height: 152)
            .onAppear {
              itemAppearAction(item.id)
            }
          }

          FeedPaginationFooterView(
            isLoading: isLoadingNextPage,
            errorMessage: nextPageErrorMessage,
            canLoadNextPage: canLoadNextPage,
            retryAction: nextPageRetryAction
          )
          .padding(.top, 12)
        }
      }
    }
  }
}
