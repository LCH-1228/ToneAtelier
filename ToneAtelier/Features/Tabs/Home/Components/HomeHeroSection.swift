//
//  HomeHeroSection.swift
//  ToneAtelier
//
//  Created by Codex on 4/24/26.
//

import SwiftUI

struct HomeHeroSection: View {
  let featuredFilter: HomeFeaturedFilter?
  let categories: [HomeCategory]
  let topSafeAreaInset: CGFloat
  let tryAction: () -> Void
  let categoryAction: (HomeCategory) -> Void

  var body: some View {
    ZStack(alignment: .topTrailing) {
      HomeRemoteImageView(
        urlString: featuredFilter?.imageURL,
        placeholderIconName: AppAsset.HomeCategory.star
      )
        .frame(height: 555)
        .overlay {
          LinearGradient(
            colors: [
              Color.clear,
              Color.black.opacity(0.26),
              HomeTheme.background.opacity(0.98),
            ],
            startPoint: .top,
            endPoint: .bottom
          )
        }
        .clipped()

      Button(action: tryAction) {
        Text("사용해보기")
          .font(HomeTheme.pretendard(size: 12, weight: .medium))
          .foregroundStyle(HomeTheme.gray60)
          .padding(.horizontal, 12)
          .frame(height: 28)
          .background(HomeTheme.tabBarBackground)
          .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
              .stroke(HomeTheme.gray75.opacity(0.5), lineWidth: 1)
          }
          .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
      }
      .buttonStyle(.plain)
      .frame(minHeight: 44, alignment: .top)
      .contentShape(Rectangle())
      .padding(.top, topSafeAreaInset + 12)
      .padding(.trailing, 20)

      VStack(alignment: .leading, spacing: 0) {
        Spacer(minLength: 236)

        VStack(alignment: .leading, spacing: 8) {
          Text("오늘의 필터 소개")
            .font(HomeTheme.pretendard(size: 12, weight: .medium))
            .foregroundStyle(HomeTheme.gray60)

          Text(featuredFilter?.title ?? "오늘의 필터가 아직 준비되지 않았어요")
            .font(HomeTheme.mulgyeol(size: 32, weight: .bold))
            .foregroundStyle(HomeTheme.gray30)
            .fixedSize(horizontal: false, vertical: true)

          Text(featuredFilter?.summary ?? "필터 소개가 도착하면 이 영역에 최신 내용이 표시됩니다.")
            .font(HomeTheme.pretendard(size: 12, weight: .regular))
            .foregroundStyle(HomeTheme.gray60)
            .lineSpacing(6)
            .padding(.top, 10)
        }
        .padding(.horizontal, 20)

        HStack(spacing: 16) {
          ForEach(categories) { category in
            Button {
              categoryAction(category)
            } label: {
              VStack(spacing: 2) {
                Image(category.assetName)
                  .renderingMode(.template)
                  .resizable()
                  .scaledToFit()
                  .foregroundStyle(HomeTheme.background)
                  .frame(width: 32, height: 32)

                Text(category.title)
                  .font(HomeTheme.pretendard(size: 10, weight: .semibold))
                  .foregroundStyle(HomeTheme.gray60)
              }
              .frame(width: 56, height: 56)
              .background(HomeTheme.tabBarBackground)
              .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                  .stroke(HomeTheme.gray75.opacity(0.5), lineWidth: 1)
              }
              .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
          }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 22)
        .padding(.bottom, 22)
      }
    }
  }
}
