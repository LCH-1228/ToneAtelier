//
//  ProfileEditAvatarSection.swift
//  ToneAtelier
//
//  Created by Codex on 5/1/26.
//

import SwiftUI

struct ProfileEditAvatarSection: View {
  let avatarURL: String?
  let changePhotoAction: () -> Void

  var body: some View {
    VStack(spacing: 10) {
      avatar

      Button(action: changePhotoAction) {
        HStack(spacing: 6) {
          Image(systemName: "camera")
            .font(AppTheme.symbol(size: 14, weight: .medium))
            .foregroundStyle(AppTheme.gray60)
          Text("사진 변경")
            .font(AppTheme.pretendard(size: 12, weight: .bold))
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
      .accessibilityLabel("사진 변경")
    }
  }

  private var avatar: some View {
    // 향후 avatarURL이 있으면 AsyncImage로 교체. 본 단계는 단색 + person 아이콘 placeholder.
    ZStack {
      Circle()
        .fill(AppTheme.deepTurquoise)
      Image(systemName: "person.fill")
        .font(AppTheme.symbol(size: 40, weight: .medium))
        .foregroundStyle(AppTheme.gray60)
    }
    .frame(width: 92, height: 92)
    .overlay {
      Circle()
        .stroke(AppTheme.brightTurquoise, lineWidth: 3)
    }
  }
}

#Preview {
  ProfileEditAvatarSection(avatarURL: nil, changePhotoAction: {})
    .padding()
    .background(AppTheme.background)
    .preferredColorScheme(.dark)
}
