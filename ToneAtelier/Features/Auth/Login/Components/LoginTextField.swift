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
    AuthTextField(
      title: title,
      placeholder: placeholder,
      text: $text,
      isSecure: isSecure
    )
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
