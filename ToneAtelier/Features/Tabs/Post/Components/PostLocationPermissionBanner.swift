//
//  PostLocationPermissionBanner.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//
//  위치 권한 거부 시 상단에 노출되는 안내 배너. 노출 분기는 다음 호출에서 PostFeature.State.isLocationDenied로 제어.
//

import SwiftUI

struct PostLocationPermissionBanner: View {
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Image(systemName: "location.slash")
          .font(AppTheme.symbol(size: 14, weight: .semibold))
          .foregroundStyle(AppTheme.gray30)

        VStack(alignment: .leading, spacing: 2) {
          Text("위치 권한이 꺼져 있어요")
            .font(AppTheme.pretendard(size: 13, weight: .bold))
            .foregroundStyle(AppTheme.gray30)

          Text("주변 게시글을 보려면 권한 허용이 필요합니다")
            .font(AppTheme.pretendard(size: 12, weight: .regular))
            .foregroundStyle(AppTheme.gray60)
        }

        Spacer(minLength: 0)

        Image(systemName: "chevron.right")
          .font(AppTheme.symbol(size: 12, weight: .semibold))
          .foregroundStyle(AppTheme.gray60)
      }
      .padding(.horizontal, 14)
      .frame(height: 56)
      .background(AppTheme.deepTurquoise)
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("위치 권한 설정")
  }
}

#Preview {
  PostLocationPermissionBanner(action: {})
    .padding(20)
    .background(AppTheme.background)
    .preferredColorScheme(.dark)
}
