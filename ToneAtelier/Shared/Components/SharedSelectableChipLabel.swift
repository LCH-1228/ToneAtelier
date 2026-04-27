//
//  SharedSelectableChipLabel.swift
//  ToneAtelier
//
//  Created by Codex on 4/28/26.
//

import SwiftUI

struct SharedSelectableChipLabel: View {
  let title: String
  let isSelected: Bool

  var body: some View {
    Text(title)
      .font(HomeTheme.pretendard(size: 14, weight: isSelected ? .bold : .medium))
      .foregroundStyle(isSelected ? HomeTheme.gray45 : HomeTheme.gray75)
      .frame(height: 28)
      .padding(.horizontal, 17)
      .background(isSelected ? HomeTheme.brightTurquoise : HomeTheme.blackTurquoise)
      .clipShape(Capsule())
      .overlay {
        if isSelected {
          Capsule()
            .stroke(HomeTheme.deepTurquoise, lineWidth: 1)
        }
      }
  }
}
