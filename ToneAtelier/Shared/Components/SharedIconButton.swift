//
//  SharedIconButton.swift
//  ToneAtelier
//
//  Created by Codex on 4/28/26.
//

import SwiftUI

struct SharedIconButton<Icon: View>: View {
  let accessibilityLabel: String
  let isDisabled: Bool
  let action: () -> Void
  let icon: Icon

  init(
    accessibilityLabel: String,
    isDisabled: Bool = false,
    action: @escaping () -> Void,
    @ViewBuilder icon: () -> Icon
  ) {
    self.accessibilityLabel = accessibilityLabel
    self.isDisabled = isDisabled
    self.action = action
    self.icon = icon()
  }

  var body: some View {
    Button(action: action) {
      icon
        .frame(width: 48, height: 56)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(isDisabled)
    .opacity(isDisabled ? 0.55 : 1)
    .accessibilityLabel(accessibilityLabel)
  }
}
