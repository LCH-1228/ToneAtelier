//
//  PostMediaCarouselView.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//
//  Pencil node: c638M (d_media)
//

import SwiftUI

/// Detail 상단 미디어 캐러셀. 사진은 `ChatImageView`로 노출하고
/// 영상 확장자는 좌상단 "영상" 배지 + 중앙 play 아이콘으로 표시한다.
/// 미디어 영역 단일 탭은 `onMediaTap`으로 풀스크린 viewer 진입 신호를 위임한다.
struct PostMediaCarouselView: View {
  let files: [String]
  @Binding var currentIndex: Int
  /// 현재 표시 중인 미디어 path를 담은 `MediaPreviewItem`을 부모로 위임.
  let onMediaTap: (MediaPreviewItem) -> Void

  var body: some View {
    Group {
      if files.isEmpty {
        placeholder
      } else {
        carousel
      }
    }
    .frame(height: 220)
  }

  private var placeholder: some View {
    RoundedRectangle(cornerRadius: 16, style: .continuous)
      .fill(AppTheme.deepTurquoise)
      .overlay {
        Image(systemName: "photo")
          .font(AppTheme.symbol(size: 36, weight: .regular))
          .foregroundStyle(AppTheme.gray60)
      }
  }

  private var carousel: some View {
    TabView(selection: $currentIndex) {
      ForEach(Array(files.enumerated()), id: \.offset) { index, path in
        ZStack(alignment: .topLeading) {
          ChatImageView(
            path: path,
            baseURL: nil,
            shape: .roundedRect(cornerRadius: 16)
          )

          if MediaPathClassifier.isVideo(path) {
            videoBadge
              .padding(12)
          }

          if MediaPathClassifier.isVideo(path) {
            Image(systemName: "play.circle.fill")
              .font(AppTheme.symbol(size: 44, weight: .regular))
              .foregroundStyle(.white.opacity(0.95))
              .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
              .allowsHitTesting(false)
          }
        }
        .contentShape(.rect)
        .onTapGesture {
          if let item = MediaPreviewItem.from(files: files, tappedIndex: index) {
            onMediaTap(item)
          }
        }
        .tag(index)
      }
    }
    .tabViewStyle(.page(indexDisplayMode: files.count > 1 ? .always : .never))
    .indexViewStyle(.page(backgroundDisplayMode: files.count > 1 ? .always : .never))
  }

  private var videoBadge: some View {
    Text("영상")
      .font(AppTheme.pretendard(size: 11, weight: .bold))
      .foregroundStyle(AppTheme.gray15)
      .padding(.horizontal, 8)
      .frame(height: 22)
      .background(AppTheme.deepTurquoise.opacity(0.85))
      .clipShape(Capsule())
  }
}
