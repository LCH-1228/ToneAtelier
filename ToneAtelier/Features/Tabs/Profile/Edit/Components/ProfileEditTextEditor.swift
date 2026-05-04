//
//  ProfileEditTextEditor.swift
//  ToneAtelier
//
//  Created by Codex on 5/1/26.
//

import SwiftUI

struct ProfileEditTextEditor: View {
  let label: String
  @Binding var text: String

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(label)
        .pretendard(.body2)
        .foregroundStyle(AppTheme.gray60)

      TextEditor(text: $text)
        .font(AppTheme.Pretendard.body2.font)
        .foregroundStyle(AppTheme.gray30)
        .tint(AppTheme.brightTurquoise)
        .scrollContentBackground(.hidden)
        .padding(12)
        .frame(height: 60)
        .background(AppTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(AppTheme.deepTurquoise, lineWidth: 2)
        }
        .accessibilityLabel(label)
    }
  }
}

#Preview {
  ProfileEditTextEditor(label: "소개", text: .constant("프로필 소개입니다."))
    .padding()
    .background(AppTheme.background)
    .preferredColorScheme(.dark)
}
