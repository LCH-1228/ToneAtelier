//
//  SharedSelectableChipButton.swift
//  ToneAtelier
//
//  Created by Codex on 4/28/26.
//

import SwiftUI

struct SharedSelectableChipButton: View {
  let title: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      SharedSelectableChipLabel(title: title, isSelected: isSelected)
    }
    .buttonStyle(.plain)
  }
}
