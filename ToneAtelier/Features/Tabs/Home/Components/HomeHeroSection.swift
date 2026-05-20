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
      CachedImageView(
        urlString: featuredFilter?.imageURL,
        placeholderIconName: AppAsset.HomeCategory.star
      )
        .frame(height: 555)
        .overlay {
          LinearGradient(
            colors: [
              Color.clear,
              Color.black.opacity(0.26),
              AppTheme.background.opacity(0.98)
            ],
            startPoint: .top,
            endPoint: .bottom
          )
        }
        .clipped()

      Button(action: tryAction) {
        Text("사용해보기")
          .pretendard(.caption1)
          .foregroundStyle(AppTheme.gray60)
          .padding(.horizontal, 12)
          .frame(height: 28)
          .background(AppTheme.tabBarBackground)
          .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
              .stroke(AppTheme.gray75.opacity(0.5), lineWidth: 1)
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
            .pretendard(.body3)
            .foregroundStyle(AppTheme.gray60)

          Text(featuredFilter?.title ?? "오늘의 필터가 아직 없어요")
            .mulgyeol(.display)
            .foregroundStyle(AppTheme.gray30)
            .fixedSize(horizontal: false, vertical: true)

          Text(featuredFilter?.summary ?? "새 필터가 도착하면 가장 먼저 알려드릴게요")
            .pretendard(.captionParagraph)
            .foregroundStyle(AppTheme.gray60)
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
                  .foregroundStyle(AppTheme.background)
                  .frame(width: 32, height: 32)

                Text(category.title)
                  .pretendard(.caption2Bold)
                  .foregroundStyle(AppTheme.gray60)
              }
              .frame(width: 56, height: 56)
              .background(AppTheme.tabBarBackground)
              .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                  .stroke(AppTheme.gray75.opacity(0.5), lineWidth: 1)
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
