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

  init(store: StoreOf<HomeFeature>) {
    self.store = store
  }

  var body: some View {
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
    .navigationDestination(isPresented: bannerWebViewIsPresented) {
      if let bannerWebViewStore = store.scope(
        state: \.bannerWebView,
        action: \.bannerWebView
      ) {
        HomeBannerWebView(store: bannerWebViewStore)
      }
    }
    .navigationDestination(isPresented: feedIsPresented) {
      if let feedStore = store.scope(
        state: \.feed,
        action: \.feed
      ) {
        FeedView(store: feedStore)
      }
    }
    .navigationDestination(isPresented: detailIsPresented) {
      if let detailStore = store.scope(
        state: \.detail,
        action: \.detail
      ) {
        HomeDetailView(store: detailStore)
      }
    }
    .alert($store.scope(state: \.alert, action: \.alert))
    .background(HomeTheme.background.ignoresSafeArea())
    .ignoresSafeArea(edges: .top)
    .toolbar(.hidden, for: .navigationBar)
  }

  private var contentView: some View {
    ScrollView(showsIndicators: false) {
      VStack(alignment: .leading, spacing: 0) {
        HomeHeroSection(
          featuredFilter: store.featuredFilter,
          categories: store.categories,
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
        .padding(.bottom, 124)
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
            HomeRemoteImageView(urlString: banner.imageURL)
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
        .font(HomeTheme.pretendard(size: 10, weight: .medium))
        .foregroundStyle(HomeTheme.gray45)
        .padding(.horizontal, 11)
        .frame(height: 20)
        .background(HomeTheme.tabBarBackground)
        .overlay {
          Capsule()
            .stroke(HomeTheme.gray60.opacity(0.5), lineWidth: 1)
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

  private var bannerWebViewIsPresented: Binding<Bool> {
    Binding(
      get: {
        store.bannerWebView != nil
      },
      set: { isPresented in
        if !isPresented {
          store.send(.bannerWebViewDismissed)
        }
      }
    )
  }

  private var feedIsPresented: Binding<Bool> {
    Binding(
      get: {
        store.feed != nil
      },
      set: { isPresented in
        if !isPresented {
          store.send(.feedDismissed)
        }
      }
    )
  }

  private var detailIsPresented: Binding<Bool> {
    Binding(
      get: {
        store.detail != nil
      },
      set: { isPresented in
        if !isPresented {
          store.send(.detailDismissed)
        }
      }
    )
  }

  private var hotTrendSection: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(store.hotTrends) { trend in
          HomeTrendCard(
            trend: trend,
            isFocused: trend.id == store.focusedTrendID
          ) {
            store.send(.hotTrendTapped(trend.id))
          }
        }
      }
      .padding(.horizontal, 20)
    }
    .contentMargins(.horizontal, -20, for: .scrollContent)
  }

  private func sectionHeader(_ title: String) -> some View {
    HStack {
      Text(title)
        .font(HomeTheme.pretendard(size: 16, weight: .bold))
        .foregroundStyle(HomeTheme.gray60)

      Spacer()
    }
    .frame(height: 48)
  }

  private func emptySection(_ message: String) -> some View {
    RoundedRectangle(cornerRadius: 18, style: .continuous)
      .fill(HomeTheme.blackTurquoise)
      .overlay {
        Text(message)
          .font(HomeTheme.pretendard(size: 14, weight: .medium))
          .foregroundStyle(HomeTheme.gray75)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 24)
      }
      .frame(height: 120)
  }

  private var loadingView: some View {
    VStack(spacing: 18) {
      ProgressView()
        .tint(HomeTheme.gray45)
      Text("홈 화면을 불러오는 중입니다.")
        .font(HomeTheme.pretendard(size: 14, weight: .medium))
        .foregroundStyle(HomeTheme.gray60)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func retryView(message: String) -> some View {
    VStack(spacing: 14) {
      Text(message)
        .font(HomeTheme.pretendard(size: 14, weight: .medium))
        .foregroundStyle(HomeTheme.gray60)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 32)

      Button("다시 시도") {
        store.send(.reloadButtonTapped)
      }
      .font(HomeTheme.pretendard(size: 14, weight: .bold))
      .foregroundStyle(HomeTheme.gray45)
      .frame(height: 40)
      .padding(.horizontal, 20)
      .background(HomeTheme.deepTurquoise)
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
      HomeBanner(id: "preview-banner-3", title: "배너 3", imageURL: nil, payload: nil),
    ]
    state.hotTrends = [
      HomeTrend(id: "trend-1", title: "트렌드 1", likeCount: 30, imageURL: nil),
      HomeTrend(id: "trend-2", title: "트렌드 2", likeCount: 121, imageURL: nil),
      HomeTrend(id: "trend-3", title: "트렌드 3", likeCount: 226, imageURL: nil),
    ]
    state.focusedTrendID = "trend-2"
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
