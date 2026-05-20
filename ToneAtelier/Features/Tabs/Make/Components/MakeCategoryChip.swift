//
//  MakeCategoryChip.swift
//  ToneAtelier
//
//  Created by Codex on 4/27/26.
//

import SwiftUI

struct MakeCategoryChip: View {
  let title: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    SharedSelectableChipButton(
      title: title,
      isSelected: isSelected
    ) {
      action()
    }
  }
}
