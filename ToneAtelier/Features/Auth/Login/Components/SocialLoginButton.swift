//
//  SocialLoginButton.swift
//  ToneAtelier
//
//  Created by Codex on 4/23/26.
//

import SwiftUI

enum SocialLoginProvider {
  case kakao
  case apple

  var title: String {
    switch self {
    case .kakao:
      "카카오로 계속하기"
    case .apple:
      "Apple로 계속하기"
    }
  }

  var iconSystemName: String {
    switch self {
    case .kakao:
      "message.fill"
    case .apple:
      "apple.logo"
    }
  }

  var backgroundColor: Color {
    switch self {
    case .kakao:
      Color(red: 254 / 255, green: 229 / 255, blue: 0)
    case .apple:
      .black
    }
  }

  var foregroundColor: Color {
    switch self {
    case .kakao:
      Color.black.opacity(0.85)
    case .apple:
      .white
    }
  }
}

struct SocialLoginButton: View {
  let provider: SocialLoginProvider
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Image(systemName: provider.iconSystemName)
          .font(.headline)

        Text(provider.title)
          .font(.body.weight(.semibold))
      }
      .frame(maxWidth: .infinity)
      .frame(height: 52)
      .foregroundStyle(provider.foregroundColor)
      .background(provider.backgroundColor)
      .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    .buttonStyle(.plain)
  }
}

#Preview {
  VStack(spacing: 12) {
    SocialLoginButton(provider: .kakao) {}
    SocialLoginButton(provider: .apple) {}
  }
  .padding()
}
