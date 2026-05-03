//
//  PostLocationSelectedCardView.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//
//  Pencil node: jnSEB (selectedAddressCard)
//

import SwiftUI

struct PostLocationSelectedCardView: View {
  let address: String?
  let latitude: Double?
  let longitude: Double?

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      Text("선택된 위치")
        .font(AppTheme.pretendard(size: 11, weight: .bold))
        .foregroundStyle(AppTheme.gray75)

      Text(displayAddress)
        .font(AppTheme.pretendard(size: 14, weight: .bold))
        .foregroundStyle(AppTheme.gray30)
        .lineLimit(2)

      Text(displaySub)
        .font(AppTheme.pretendard(size: 11, weight: .semibold))
        .foregroundStyle(AppTheme.gray60)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(AppTheme.blackTurquoise)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private var displayAddress: String {
    if let address, !address.isEmpty {
      return address
    }
    if latitude != nil, longitude != nil {
      return "위치 좌표가 선택되었어요"
    }
    return "지도를 탭하거나 검색해서 위치를 선택하세요"
  }

  private var displaySub: String {
    if let latitude, let longitude {
      return String(format: "위도 %.5f · 경도 %.5f", latitude, longitude)
    }
    return "핀을 옮기거나 주소를 검색하면 위경도가 함께 갱신돼요"
  }
}

#Preview {
  VStack(spacing: 20) {
    PostLocationSelectedCardView(
      address: "서울 영등포구 선유로 9길 30",
      latitude: 37.5263,
      longitude: 126.8924
    )
    PostLocationSelectedCardView(address: nil, latitude: nil, longitude: nil)
  }
  .padding(20)
  .background(AppTheme.background)
  .preferredColorScheme(.dark)
}
