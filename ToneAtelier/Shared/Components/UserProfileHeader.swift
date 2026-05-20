//
//  UserProfileHeader.swift
//  ToneAtelier
//

import SwiftUI

struct UserProfileHeader: View {
  let name: String
  let subtitle: String
  let profileImageURL: String?
  /// 표시 대상이 현재 로그인 사용자 본인인 경우 프로필/메시지 버튼을 노출하지 않는다.
  let isSelf: Bool
  let profileAction: () -> Void
  let messageAction: () -> Void

  init(
    name: String,
    subtitle: String,
    profileImageURL: String?,
    isSelf: Bool = false,
    profileAction: @escaping () -> Void = {},
    messageAction: @escaping () -> Void = {}
  ) {
    self.name = name
    self.subtitle = subtitle
    self.profileImageURL = profileImageURL
    self.isSelf = isSelf
    self.profileAction = profileAction
    self.messageAction = messageAction
  }

  var body: some View {
    HStack(spacing: 12) {
      CachedImageView(
        urlString: profileImageURL,
        contentMode: .fill,
        placeholderIconName: AppAsset.HomeCategory.people
      )
      .frame(width: 56, height: 56)
      .overlay {
        Circle().stroke(AppTheme.gray75.opacity(0.5), lineWidth: 1)
      }
      .clipShape(Circle())

      VStack(alignment: .leading, spacing: 0) {
        Text(name)
          .mulgyeol(.body1)
          .foregroundStyle(AppTheme.gray30)

        Text(subtitle)
          .pretendard(.body1)
          .foregroundStyle(AppTheme.gray75)
      }

      Spacer()

      if !isSelf {
        Button(action: profileAction) {
          Text("프로필")
            .pretendard(.captionBold)
            .foregroundStyle(AppTheme.gray30)
            .frame(width: 54, height: 32)
            .background(AppTheme.brightTurquoise)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)

        Button(action: messageAction) {
          Image(AppAsset.Common.sendMessage)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 18, height: 18)
            .foregroundStyle(AppTheme.gray30)
            .frame(width: 32, height: 32)
            .background(AppTheme.deepTurquoise)
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
      }
    }
  }
}
