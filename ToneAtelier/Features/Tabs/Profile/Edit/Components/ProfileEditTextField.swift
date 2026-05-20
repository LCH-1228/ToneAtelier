//
//  ProfileEditTextField.swift
//  ToneAtelier
//
//  Created by Codex on 5/1/26.
//

import SwiftUI

struct ProfileEditTextField: View {
  let label: String
  @Binding var text: String
  var isReadOnly: Bool = false

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(label)
        .pretendard(.body2)
        .foregroundStyle(AppTheme.gray60)

      TextField("", text: $text)
        .font(AppTheme.Pretendard.body2.font)
        .foregroundStyle(isReadOnly ? AppTheme.gray75 : AppTheme.gray30)
        .tint(AppTheme.brightTurquoise)
        .disabled(isReadOnly)
        .padding(.horizontal, 12)
        .frame(height: 44)
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
  VStack(spacing: 12) {
    ProfileEditTextField(label: "닉네임", text: .constant("sesac"))
    ProfileEditTextField(label: "이메일", text: .constant("sesac@sesac.com"), isReadOnly: true)
    ProfileEditTextField(label: "전화번호", text: .constant("010-1234-1234"))
  }
  .padding()
  .background(AppTheme.background)
  .preferredColorScheme(.dark)
}
