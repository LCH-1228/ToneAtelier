//
//  PostMediaCarouselView.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//

import SwiftUI

struct PostMediaCarouselView: View {
  let files: [String]
  @Binding var currentIndex: Int
  /// 사진 탭만 위임. 영상 탭은 VideoMediaView가 자체 처리.
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
        page(for: path, index: index)
          .tag(index)
      }
    }
    .tabViewStyle(.page(indexDisplayMode: files.count > 1 ? .always : .never))
    .indexViewStyle(.page(backgroundDisplayMode: files.count > 1 ? .always : .never))
  }

  @ViewBuilder
  private func page(for path: String, index: Int) -> some View {
    Color.clear
      .overlay {
        if MediaPathClassifier.isVideo(path) {
          VideoMediaView(path: path, shape: .roundedRect(cornerRadius: 16))
        } else {
          ChatImageView(
            path: path,
            baseURL: nil,
            shape: .roundedRect(cornerRadius: 16)
          )
          .contentShape(.rect)
          .onTapGesture {
            if let item = MediaPreviewItem.from(files: files, tappedIndex: index) {
              onMediaTap(item)
            }
          }
        }
      }
      .clipped()
  }
}
