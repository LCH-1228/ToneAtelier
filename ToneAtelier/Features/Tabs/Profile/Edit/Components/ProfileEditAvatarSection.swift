//
//  ProfileEditAvatarSection.swift
//  ToneAtelier
//
//  Created by Codex on 5/1/26.
//

import PhotosUI
import SwiftUI
import UIKit

struct ProfileEditAvatarSection: View {
  let avatarURL: String?
  let pendingImageData: Data?
  @Binding var photoSelection: PhotosPickerItem?
  @State private var renderedImage: UIImage?

  var body: some View {
    VStack(spacing: 10) {
      avatar

      PhotosPicker(selection: $photoSelection, matching: .images, photoLibrary: .shared()) {
        HStack(spacing: 6) {
          Image(systemName: "camera")
            .font(AppTheme.symbol(size: 14, weight: .medium))
            .foregroundStyle(AppTheme.gray60)
          Text("사진 변경")
            .pretendard(.captionBold)
            .foregroundStyle(AppTheme.gray60)
        }
        .padding(.horizontal, 14)
        .frame(height: 30)
        .background(AppTheme.blackTurquoise)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: 15, style: .continuous)
            .stroke(AppTheme.deepTurquoise, lineWidth: 1)
        }
      }
      .buttonStyle(.plain)
      .accessibilityLabel("사진 변경")
    }
    .task(id: pendingImageData) {
      // pendingImageData가 바뀔 때만 디코딩. 다른 State 변경 시 매 렌더 디코딩 회피.
      renderedImage = pendingImageData.flatMap(UIImage.init(data:))
    }
  }

  @ViewBuilder
  private var avatar: some View {
    // renderedImage(편집 중 신규 선택, 사전 디코딩) > avatarURL(서버 보유) > placeholder 우선순위.
    ZStack {
      Circle()
        .fill(AppTheme.deepTurquoise)

      if let renderedImage {
        Image(uiImage: renderedImage)
          .resizable()
          .scaledToFill()
          .clipShape(Circle())
      } else if let avatarURL, !avatarURL.isEmpty {
        CachedImageView(urlString: avatarURL)
          .scaledToFill()
          .clipShape(Circle())
      } else {
        Image(systemName: "person.fill")
          .font(AppTheme.symbol(size: 40, weight: .medium))
          .foregroundStyle(AppTheme.gray60)
      }
    }
    .frame(width: 92, height: 92)
    .overlay {
      Circle()
        .stroke(AppTheme.brightTurquoise, lineWidth: 3)
    }
  }
}

#Preview {
  StatefulPreviewWrapper(nil as PhotosPickerItem?) { selection in
    ProfileEditAvatarSection(
      avatarURL: nil,
      pendingImageData: nil,
      photoSelection: selection
    )
    .padding()
    .background(AppTheme.background)
    .preferredColorScheme(.dark)
  }
}

private struct StatefulPreviewWrapper<Value, Content: View>: View {
  @State private var value: Value
  let content: (Binding<Value>) -> Content

  init(_ initial: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
    self._value = State(initialValue: initial)
    self.content = content
  }

  var body: some View {
    content($value)
  }
}
