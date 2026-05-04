//
//  CreatorStoreHeroCard.swift
//  ToneAtelier
//
//  Created by Codex on 5/1/26.
//

import SwiftUI

/// 작가 스토어 hero 카드. Pencil `YwFLY` (Store Hero) 매핑.
struct CreatorStoreHeroCard: View {
  let hero: CreatorStoreHero

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      HomeRemoteImageView(
        urlString: hero.profileImageURL,
        placeholderIconName: AppAsset.HomeCategory.people
      )
      .frame(width: 82, height: 82)
      .clipShape(Circle())
      .overlay {
        Circle()
          .stroke(AppTheme.brightTurquoise, lineWidth: 3)
      }

      VStack(alignment: .leading, spacing: 6) {
        Text(hero.nickname)
          .mulgyeol(.pageTitle)
          .foregroundStyle(AppTheme.gray30)
          .lineLimit(1)

        Text(hero.subline)
          .pretendard(.captionBold)
          .foregroundStyle(AppTheme.gray75)
          .lineLimit(1)

        if let introduction = hero.introduction, !introduction.isEmpty {
          Text(introduction)
            .pretendard(.caption1)
            .foregroundStyle(AppTheme.gray60)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(AppTheme.blackTurquoise)
    .overlay {
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .stroke(AppTheme.deepTurquoise, lineWidth: 1)
    }
    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
  }
}

#Preview {
  VStack(spacing: 16) {
    CreatorStoreHeroCard(
      hero: CreatorStoreHero(
        nickname: "청록 새록",
        name: "YOON SESAC",
        introduction: "자연광과 인물 톤을 중심으로 한 감성 프리셋 스토어",
        profileImageURL: nil,
        filterCount: 24
      )
    )

    CreatorStoreHeroCard(
      hero: CreatorStoreHero(
        nickname: "필터 마스터",
        name: nil,
        introduction: nil,
        profileImageURL: nil,
        filterCount: 0
      )
    )
  }
  .padding(20)
  .background(AppTheme.background)
  .preferredColorScheme(.dark)
}
