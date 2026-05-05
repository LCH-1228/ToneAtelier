//
//  HomeView.swift
//  ToneAtelier
//
//  Created by Codex on 4/24/26.
//

import ComposableArchitecture
import SwiftUI

struct HomeView: View {
  @Bindable var store: StoreOf<HomeFeature>
  @State private var trendSectionWidth: CGFloat = 0
  private let topSafeAreaInset: CGFloat

  init(store: StoreOf<HomeFeature>, topSafeAreaInset: CGFloat = 0) {
    self.store = store
    self.topSafeAreaInset = topSafeAreaInset
  }

  var body: some View {
    NavigationStack(
      path: $store.scope(state: \.path, action: \.path)
    ) {
      Group {
        if store.isLoading && !store.hasContent {
          loadingView
        } else if let errorMessage = store.errorMessage, !store.hasContent {
          retryView(message: errorMessage)
        } else {
          contentView
        }
      }
      .task {
        await store.send(.task).finish()
      }
      .alert($store.scope(state: \.alert, action: \.alert))
      .background(AppTheme.background.ignoresSafeArea())
      .ignoresSafeArea(edges: .top)
      .toolbar(.hidden, for: .navigationBar)
    } destination: { store in
      switch store.case {
      case let .bannerWeb(store):
        HomeBannerWebView(store: store)
      case let .detail(store):
        HomeDetailView(store: store)
      }
    }
  }

  private var contentView: some View {
    ScrollView(showsIndicators: false) {
      VStack(alignment: .leading, spacing: 0) {
        HomeHeroSection(
          featuredFilter: store.featuredFilter,
          categories: store.categories,
          topSafeAreaInset: topSafeAreaInset,
          tryAction: {
            store.send(.tryFeaturedFilterButtonTapped)
          },
          categoryAction: { category in
            store.send(.categoryTapped(category))
          }
        )

        VStack(alignment: .leading, spacing: 28) {
          if !store.banners.isEmpty {
            featuredBannerSection
              .padding(.top, 12)
          }

          sectionHeader("핫 트렌드")

          if store.hotTrends.isEmpty {
            emptySection("핫 트렌드가 아직 준비되지 않았어요.")
          } else {
            hotTrendSection
          }

          sectionHeader("오늘의 작가 소개")
            .padding(.top, 14)

          if let author = store.featuredAuthor {
            HomeAuthorSection(author: author)
          } else {
            emptySection("오늘의 작가 정보를 곧 보여드릴게요.")
          }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, MainTabBarView.Layout.contentInsetHeight + 32)
      }
    }
  }

  private var featuredBannerSection: some View {
    ZStack(alignment: .bottomTrailing) {
      TabView(selection: bannerSelection) {
        ForEach(Array(store.banners.enumerated()), id: \.element.id) { index, banner in
          Button {
            store.send(.bannerTapped(banner.id))
          } label: {
            CachedImageView(urlString: banner.imageURL)
              .frame(height: 100)
              .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
          }
          .buttonStyle(.plain)
          .tag(index)
        }
      }
      .frame(height: 100)
      .tabViewStyle(.page(indexDisplayMode: .never))

      Text("\(store.currentBannerIndex + 1) / \(store.banners.count)")
        .pretendard(.caption2)
        .foregroundStyle(AppTheme.gray45)
        .padding(.horizontal, 11)
        .frame(height: 20)
        .background(AppTheme.tabBarBackground)
        .overlay {
          Capsule()
            .stroke(AppTheme.gray60.opacity(0.5), lineWidth: 1)
        }
        .clipShape(Capsule())
        .padding(.trailing, 10)
        .padding(.bottom, 12)
    }
  }

  private var bannerSelection: Binding<Int> {
    Binding(
      get: {
        store.currentBannerIndex
      },
      set: { newValue in
        store.send(.bannerIndexChanged(newValue))
      }
    )
  }

  private var hotTrendSection: some View {
    let sideInset = max(0, (trendSectionWidth - 200) / 2)
    return ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(store.hotTrends) { trend in
          HomeTrendCard(
            trend: trend,
            isFocused: trend.id == store.focusedTrendID
          ) {
            store.send(.hotTrendTapped(trend.id), animation: .easeInOut(duration: 0.3))
          }
        }
      }
      .scrollTargetLayout()
    }
    .scrollTargetBehavior(.viewAligned)
    .scrollPosition(id: hotTrendScrollPosition)
    .contentMargins(.horizontal, sideInset, for: .scrollContent)
    .onGeometryChange(for: CGFloat.self) { proxy in
      proxy.size.width
    } action: { newWidth in
      trendSectionWidth = newWidth
    }
    .padding(.horizontal, -20)
  }

  private var hotTrendScrollPosition: Binding<HomeTrend.ID?> {
    Binding(
      get: { store.focusedTrendID },
      set: { id in
        store.send(.hotTrendScrollPositionChanged(id))
      }
    )
  }

  private func sectionHeader(_ title: String) -> some View {
    HStack {
      Text(title)
        .pretendard(.body1)
        .foregroundStyle(AppTheme.gray60)

      Spacer()
    }
    .frame(height: 48)
  }

  private func emptySection(_ message: String) -> some View {
    RoundedRectangle(cornerRadius: 18, style: .continuous)
      .fill(AppTheme.blackTurquoise)
      .overlay {
        Text(message)
          .pretendard(.body2)
          .foregroundStyle(AppTheme.gray75)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 24)
      }
      .frame(height: 120)
  }

  private var loadingView: some View {
    VStack(spacing: 18) {
      ProgressView()
        .tint(AppTheme.gray45)
      Text("홈 화면을 불러오는 중입니다.")
        .pretendard(.body2)
        .foregroundStyle(AppTheme.gray60)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func retryView(message: String) -> some View {
    VStack(spacing: 14) {
      Text(message)
        .pretendard(.body2)
        .foregroundStyle(AppTheme.gray60)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 32)

      Button("다시 시도") {
        store.send(.reloadButtonTapped)
      }
      .pretendard(.body2)
      .foregroundStyle(AppTheme.gray45)
      .frame(height: 40)
      .padding(.horizontal, 20)
      .background(AppTheme.deepTurquoise)
      .clipShape(Capsule())
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

#Preview {
  let previewState: HomeFeature.State = {
    var state = HomeFeature.State()
    state.hasLoaded = true
    state.featuredFilter = HomeFeaturedFilter(
      id: "preview-filter",
      title: "필터 제목\n필터 이름",
      summary: "필터 설명이 표시되는 영역입니다.",
      imageURL: nil
    )
    state.banners = [
      HomeBanner(id: "preview-banner-1", title: "배너 1", imageURL: nil, payload: nil),
      HomeBanner(id: "preview-banner-2", title: "배너 2", imageURL: nil, payload: nil),
      HomeBanner(id: "preview-banner-3", title: "배너 3", imageURL: nil, payload: nil)
    ]
    state.hotTrends = [
      HomeTrend(id: "trend-1", title: "트렌드 1", likeCount: 30, imageURL: nil),
      HomeTrend(id: "trend-2", title: "트렌드 2", likeCount: 121, imageURL: nil),
      HomeTrend(id: "trend-3", title: "트렌드 3", likeCount: 226, imageURL: nil)
    ]
    state.focusedTrendID = "trend-1"
    state.featuredAuthor = HomeAuthor(
      id: "preview-author",
      name: "작가 이름",
      subtitle: "AUTHOR SUBTITLE",
      portraitURL: nil,
      galleryImageURLs: [],
      tags: ["#태그1", "#태그2", "#태그3"],
      quote: "\"작가 소개 문구가 표시됩니다.\"",
      description: "작가 설명이 표시되는 영역입니다."
    )
    return state
  }()

  NavigationStack {
    HomeView(
      store: Store(initialState: previewState) {
        HomeFeature()
      }
    )
  }
}
