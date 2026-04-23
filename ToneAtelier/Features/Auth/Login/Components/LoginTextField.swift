//
//  LoginTextField.swift
//  ToneAtelier
//
//  Created by Codex on 4/23/26.
//

import SwiftUI

struct LoginTextField: View {
  let title: String
  let placeholder: String
  @Binding var text: String
  var isSecure = false

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.white.opacity(0.72))

      Group {
        if isSecure {
          SecureField(placeholder, text: $text)
        } else {
          TextField(placeholder, text: $text)
        }
      }
      .textInputAutocapitalization(.never)
      .autocorrectionDisabled()
      .foregroundStyle(.white)
      .padding(.horizontal, 16)
      .frame(height: 52)
      .background(.white.opacity(0.08))
      .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(.white.opacity(0.13), lineWidth: 1)
      }
    }
  }
}

#Preview {
  LoginTextField(
    title: "아이디",
    placeholder: "아이디를 입력해 주세요",
    text: .constant("")
  )
  .padding()
}
