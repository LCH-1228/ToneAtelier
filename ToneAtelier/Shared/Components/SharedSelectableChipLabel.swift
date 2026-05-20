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
      .pretendard(.body2)
      .foregroundStyle(isSelected ? AppTheme.gray45 : AppTheme.gray75)
      .frame(height: 28)
      .padding(.horizontal, 17)
      .background(isSelected ? AppTheme.brightTurquoise : AppTheme.blackTurquoise)
      .clipShape(Capsule())
      .overlay {
        if isSelected {
          Capsule()
            .stroke(AppTheme.deepTurquoise, lineWidth: 1)
        }
      }
  }
}
