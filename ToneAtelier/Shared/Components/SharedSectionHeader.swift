//
//  SharedSectionHeader.swift
//  ToneAtelier
//
//  Created by Codex on 4/28/26.
//

import SwiftUI

struct SharedSectionHeader: View {
  let leading: String
  let trailing: String

  var body: some View {
    HStack {
      Text(leading)
        .lineLimit(1)
        .truncationMode(.tail)

      Spacer(minLength: 12)

      Text(trailing)
        .lineLimit(1)
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
