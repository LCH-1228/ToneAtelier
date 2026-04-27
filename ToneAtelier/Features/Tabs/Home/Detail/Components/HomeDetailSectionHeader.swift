//
//  HomeDetailSectionHeader.swift
//  ToneAtelier
//
//  Created by Codex on 4/27/26.
//

import SwiftUI

struct HomeDetailSectionHeader: View {
  let leading: String
  let trailing: String

  var body: some View {
    HStack {
      Text(leading)
      Spacer()
      Text(trailing)
    }
    .font(HomeTheme.pretendard(size: 12, weight: .semibold))
    .foregroundStyle(HomeTheme.deepTurquoise)
    .padding(.horizontal, 12)
    .frame(height: 28)
    .background(HomeTheme.blackTurquoise.opacity(0.55))
    .overlay {
      RoundedRectangle(cornerRadius: 4, style: .continuous)
        .stroke(HomeTheme.deepTurquoise.opacity(0.9), lineWidth: 1)
    }
  }
}
