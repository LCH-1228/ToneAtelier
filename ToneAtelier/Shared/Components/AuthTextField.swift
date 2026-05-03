//
//  AuthTextField.swift
//  ToneAtelier
//
//  Created by Codex on 4/23/26.
//

import SwiftUI
import UIKit

struct AuthTextField: View {
  let title: String
  let placeholder: String
  @Binding var text: String
  var isSecure = false
  var keyboardType: UIKeyboardType = .default
  var accessibilityID: String? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.white.opacity(0.72))

      Group {
        if isSecure {
          SecureField(placeholder, text: $text)
            .modifier(OptionalAccessibilityIdentifier(identifier: accessibilityID))
        } else {
          TextField(placeholder, text: $text)
            .modifier(OptionalAccessibilityIdentifier(identifier: accessibilityID))
        }
      }
      .textInputAutocapitalization(.never)
      .autocorrectionDisabled()
      .keyboardType(keyboardType)
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

/// nil이면 식별자를 부여하지 않아 기본 동작을 유지하고, 값이 있으면 명시적으로 부여한다.
private struct OptionalAccessibilityIdentifier: ViewModifier {
  let identifier: String?

  func body(content: Content) -> some View {
    if let identifier {
      content.accessibilityIdentifier(identifier)
    } else {
      content
    }
  }
}

#Preview {
  AuthTextField(
    title: "이메일",
    placeholder: "name@example.com",
    text: .constant("")
  )
  .padding()
  .background(Color.black)
}
