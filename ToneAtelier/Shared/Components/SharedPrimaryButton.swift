//
//  SharedPrimaryButton.swift
//  ToneAtelier
//
//  Created by Codex on 4/28/26.
//

import SwiftUI

struct SharedPrimaryButton: View {
  let title: String
  let isDisabled: Bool
  let action: () -> Void

  init(
    title: String,
    isDisabled: Bool = false,
    action: @escaping () -> Void
  ) {
    self.title = title
    self.isDisabled = isDisabled
    self.action = action
  }

  var body: some View {
    Button(action: action) {
      Text(title)
        .font(AppTheme.pretendard(size: 20, weight: .bold))
        .foregroundStyle(isDisabled ? AppTheme.gray75 : AppTheme.gray30)
        .frame(maxWidth: .infinity)
        .frame(height: 46)
        .background(isDisabled ? Color(hex: 0x434347) : AppTheme.brightTurquoise)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    .buttonStyle(.plain)
    .disabled(isDisabled)
  }
}
