//
//  FeedView.swift
//  ToneAtelier
//
//  Created by Codex on 4/25/26.
//

import ComposableArchitecture
import SwiftUI

struct FeedView: View {
  @Environment(\.dismiss) private var dismiss

  let store: StoreOf<FeedFeature>
  var backAction: (() -> Void)?

  init(
    store: StoreOf<FeedFeature>,
    backAction: (() -> Void)? = nil
  ) {
    self.store = store
    self.backAction = backAction
  }

  var body: some View {
    GeometryReader { proxy in
      let topSafeAreaInset = max(proxy.safeAreaInsets.top, 44)

      ZStack(alignment: .top) {
        HomeTheme.background
          .ignoresSafeArea()

        ScrollView(showsIndicators: false) {
          VStack(spacing: 0) {
            Color.clear
              .frame(height: topSafeAreaInset + 56)

            sectionTitle("Top Ranking")
              .frame(height: 59)

            sortButtonRow
              .frame(height: 44)

            Color.clear
              .frame(height: 24)

            FeedRankingCarousel(items: store.rankingItems)
              .frame(height: 474)

            Color.clear
              .frame(height: 16)

            feedHeader
              .frame(height: 59)

            Group {
              switch store.displayMode {
              case .list:
                FeedListLayout(
                  items: store.filterItems,
                  isLoading: store.isLoading,
                  errorMessage: store.errorMessage
                ) {
                  store.send(.refreshButtonTapped)
                }
              case .block:
                FeedBlockLayout(
                  items: store.filterItems,
                  isLoading: store.isLoading,
                  errorMessage: store.errorMessage
                ) {
                  store.send(.refreshButtonTapped)
                }
              }
            }
            .padding(.bottom, 132)
          }
          .frame(maxWidth: .infinity)
        }

        FeedNavigationHeader {
          if let backAction {
            backAction()
          } else {
            dismiss()
          }
        }
        .padding(.top, topSafeAreaInset)
      }
    }
    .background(HomeTheme.background.ignoresSafeArea())
    .navigationBarBackButtonHidden(true)
    .toolbar(.hidden, for: .navigationBar)
    .ignoresSafeArea(edges: .top)
    .preferredColorScheme(.dark)
    .task {
      await store.send(.task).finish()
    }
  }

  private func sectionTitle(_ title: String) -> some View {
    HStack {
      Text(title)
        .font(HomeTheme.pretendard(size: 16, weight: .bold))
        .foregroundStyle(HomeTheme.gray60)

      Spacer()
    }
    .padding(.horizontal, 20)
  }

  private var sortButtonRow: some View {
    HStack(spacing: 8) {
      Spacer()

      FeedSortChip(title: "인기순", isSelected: true)
      FeedSortChip(title: "구매순", isSelected: false)
      FeedSortChip(title: "최신순", isSelected: false)
    }
    .padding(.horizontal, 20)
  }

  private var feedHeader: some View {
    HStack {
      Text("Filter Feed")
        .font(HomeTheme.pretendard(size: 16, weight: .bold))
        .foregroundStyle(HomeTheme.gray60)

      Spacer()

      Button {
        store.send(.displayModeButtonTapped, animation: .easeInOut(duration: 0.18))
      } label: {
        Text(store.displayMode.title)
          .font(HomeTheme.pretendard(size: 16, weight: .medium))
          .foregroundStyle(HomeTheme.gray75)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("피드 표시 모드 전환")
    }
    .padding(.horizontal, 20)
  }
}

private struct FeedNavigationHeader: View {
  let backAction: () -> Void

  var body: some View {
    HStack {
      Button(action: backAction) {
        Image(systemName: "chevron.left")
          .font(.system(size: 22, weight: .medium))
          .foregroundStyle(HomeTheme.gray75)
          .frame(width: 48, height: 48)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("뒤로 가기")

      Spacer()

      Text("FEED")
        .font(HomeTheme.mulgyeol(size: 20, weight: .bold))
        .foregroundStyle(HomeTheme.gray60)

      Spacer()

      Color.clear
        .frame(width: 48, height: 48)
    }
    .frame(height: 56)
    .padding(.horizontal, 4)
  }
}

private struct FeedSortChip: View {
  let title: String
  let isSelected: Bool

  var body: some View {
    Text(title)
      .font(HomeTheme.pretendard(size: 14, weight: isSelected ? .bold : .medium))
      .foregroundStyle(isSelected ? HomeTheme.gray45 : HomeTheme.gray75)
      .padding(.horizontal, 17)
      .frame(height: 28)
      .background(isSelected ? HomeTheme.brightTurquoise : HomeTheme.blackTurquoise)
      .overlay {
        if isSelected {
          Capsule()
            .stroke(HomeTheme.deepTurquoise, lineWidth: 1)
        }
      }
      .clipShape(Capsule())
  }
}

private struct FeedRankingCarousel: View {
  let items: [FeedRankingItem]

  var body: some View {
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
            .position(x: -33, y: 275.5)
        }

        if let thirdItem = items[safe: 2] {
          FeedRankingCard(item: thirdItem, isFocused: false)
            .frame(width: 220, height: 397)
            .position(x: 423, y: 275.5)
        }

        if let firstItem = items.first {
          FeedRankingCard(item: firstItem, isFocused: true)
            .frame(width: 220, height: 397)
            .position(x: 195, y: 198.5)
        }
      }
    }
    .frame(maxWidth: .infinity)
    .clipped()
  }
}

private struct FeedRankingCard: View {
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

private struct FeedListLayout: View {
  let items: [FeedFilterItem]
  let isLoading: Bool
  let errorMessage: String?
  let refreshAction: () -> Void

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
        VStack(spacing: 0) {
          ForEach(items) { item in
            FeedListItemView(item: item)
              .frame(height: 152)
          }
        }
      }
    }
  }
}

private struct FeedListItemView: View {
  let item: FeedFilterItem

  var body: some View {
    HStack(spacing: 20) {
      ZStack(alignment: .bottomTrailing) {
        HomeRemoteImageView(
          urlString: item.imageURL,
          placeholderIconName: AppAsset.HomeCategory.star
        )
          .frame(width: 100, height: 120)
          .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

        Image(AppAsset.Common.heartFilled)
          .renderingMode(.template)
          .resizable()
          .scaledToFit()
          .frame(width: 18, height: 18)
          .foregroundStyle(item.isLiked ? HomeTheme.gray15 : HomeTheme.gray45)
          .padding(8)
      }

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
    }
    .padding(.horizontal, 20)
  }
}

private struct FeedBlockLayout: View {
  let items: [FeedFilterItem]
  let isLoading: Bool
  let errorMessage: String?
  let refreshAction: () -> Void

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
        HStack(alignment: .top, spacing: 12) {
          VStack(spacing: 24) {
            if let firstItem = items[safe: 0] {
              FeedBlockItemView(item: firstItem, imageHeight: 226)
            }
            if let fourthItem = items[safe: 3] {
              FeedBlockItemView(item: fourthItem, imageHeight: 128)
            }
          }

          VStack(spacing: 24) {
            if let secondItem = items[safe: 1] {
              FeedBlockItemView(item: secondItem, imageHeight: 128)
            }
            if let thirdItem = items[safe: 2] {
              FeedBlockItemView(item: thirdItem, imageHeight: 210)
            }
          }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
      }
    }
  }
}

private struct FeedBlockItemView: View {
  let item: FeedFilterItem
  let imageHeight: CGFloat

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      ZStack(alignment: .topLeading) {
        HomeRemoteImageView(
          urlString: item.imageURL,
          placeholderIconName: AppAsset.HomeCategory.star
        )
          .frame(height: imageHeight)
          .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

        Text(item.title)
          .font(HomeTheme.mulgyeol(size: 14))
          .foregroundStyle(HomeTheme.gray30)
          .padding(.leading, 12)
          .padding(.top, 8)
          .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)

        HStack(spacing: 2) {
          Image(AppAsset.Common.heartFilled)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 13, height: 13)

          Text("\(item.likeCount)")
            .font(HomeTheme.pretendard(size: 12, weight: .semibold))
        }
        .foregroundStyle(HomeTheme.gray30)
        .padding(.trailing, 10)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
      }

      Text(item.author)
        .font(HomeTheme.pretendard(size: 12, weight: .medium))
        .foregroundStyle(Color(hex: 0x434347))
        .padding(.leading, 12)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct FeedEmptyStateView: View {
  let message: String
  let actionTitle: String?
  let action: (() -> Void)?

  var body: some View {
    VStack(spacing: 12) {
      Text(message)
        .font(HomeTheme.pretendard(size: 14, weight: .medium))
        .foregroundStyle(HomeTheme.gray75)
        .multilineTextAlignment(.center)

      if let actionTitle, let action {
        Button(action: action) {
          Text(actionTitle)
            .font(HomeTheme.pretendard(size: 14, weight: .bold))
            .foregroundStyle(HomeTheme.gray45)
            .padding(.horizontal, 18)
            .frame(height: 32)
            .background(HomeTheme.blackTurquoise)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
      }
    }
    .frame(maxWidth: .infinity)
    .frame(height: 152)
  }
}

private extension Array {
  subscript(safe index: Int) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}

#Preview {
  NavigationStack {
    FeedView(
      store: Store(
        initialState: FeedFeature.State(category: .food)
      ) {
        FeedFeature()
      }
    )
  }
}
