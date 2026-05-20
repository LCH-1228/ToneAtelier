//
//  MakeFormField.swift
//  ToneAtelier
//
//  Created by Codex on 4/27/26.
//

import SwiftUI

struct MakeFormField: View {
  let placeholder: String
  @Binding var text: String
  var trailingText: String?

  var body: some View {
    HStack(spacing: 8) {
      TextField("", text: $text, prompt: prompt)
        .font(AppTheme.Pretendard.body2.font)
        .foregroundStyle(AppTheme.gray60)
        .tint(AppTheme.brightTurquoise)

      if let trailingText {
        Text(trailingText)
          .pretendard(.body2)
          .foregroundStyle(AppTheme.gray75)
      }
    }
    .padding(.horizontal, 12)
    .frame(height: 42)
    .background(AppTheme.background)
    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .stroke(AppTheme.deepTurquoise, lineWidth: 2)
    }
  }

  private var prompt: Text {
    Text(placeholder)
      .foregroundStyle(AppTheme.deepTurquoise)
      .font(AppTheme.Pretendard.body2.font)
      .tracking(AppTheme.Pretendard.body2.tracking)
  }
}
