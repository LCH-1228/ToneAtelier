//
//  PostWriteLocationCellView.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//
//  Pencil node: lGCDX (e_locationBox) + v5JH3 (Location Select Cell)
//

import SwiftUI

struct PostWriteLocationCellView: View {
  let address: String?
  let location: GeolocationDTO?
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 10) {
        Image(systemName: "mappin.and.ellipse")
          .font(AppTheme.symbol(size: 20, weight: .regular))
          .foregroundStyle(AppTheme.brightTurquoise)
          .frame(width: 28, height: 28)

        VStack(alignment: .leading, spacing: 4) {
          Text("위치 *")
            .font(AppTheme.pretendard(size: 11, weight: .bold))
            .foregroundStyle(AppTheme.gray75)
          Text(primaryText)
            .font(AppTheme.pretendard(size: 13, weight: .bold))
            .foregroundStyle(AppTheme.gray30)
            .lineLimit(1)
            .truncationMode(.tail)
          Text(secondaryText)
            .font(AppTheme.pretendard(size: 11, weight: .semibold))
            .foregroundStyle(AppTheme.gray60)
            .lineLimit(1)
            .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        Image(systemName: "chevron.right")
          .font(AppTheme.symbol(size: 14, weight: .regular))
          .foregroundStyle(AppTheme.gray60)
      }
      .padding(12)
      .background(AppTheme.blackTurquoise)
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("위치 선택")
    .accessibilityIdentifier("post_write_location_cell")
  }

  private var primaryText: String {
    if let address, !address.isEmpty {
      return address
    }
    if let location {
      return String(format: "%.4f, %.4f", location.latitude, location.longitude)
    }
    return "위치를 선택해 주세요"
  }

  private var secondaryText: String {
    if location == nil {
      return "탭해서 지도에서 핀을 선택하거나 주소를 검색"
    }
    return "탭해서 위치 변경"
  }
}
