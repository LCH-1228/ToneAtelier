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
        .font(HomeTheme.pretendard(size: 14, weight: .medium))
        .foregroundStyle(HomeTheme.gray60)
        .tint(HomeTheme.brightTurquoise)

      if let trailingText {
        Text(trailingText)
          .font(HomeTheme.pretendard(size: 14, weight: .bold))
          .foregroundStyle(HomeTheme.gray75)
      }
    }
    .padding(.horizontal, 12)
    .frame(height: 42)
    .background(HomeTheme.background)
    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .stroke(HomeTheme.deepTurquoise, lineWidth: 2)
    }
  }

  private var prompt: Text {
    Text(placeholder)
      .foregroundStyle(HomeTheme.deepTurquoise)
      .font(HomeTheme.pretendard(size: 14, weight: .medium))
  }
}
