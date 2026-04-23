//
//  LoginView.swift
//  ToneAtelier
//
//  Created by Codex on 4/23/26.
//

import ComposableArchitecture
import SwiftUI

struct LoginView: View {
  @Bindable var store: StoreOf<LoginFeature>

  init(store: StoreOf<LoginFeature>) {
    self.store = store
  }

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [
          Color(red: 0.03, green: 0.04, blue: 0.06),
          Color(red: 0.06, green: 0.08, blue: 0.11)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()

      ScrollView {
        VStack(alignment: .center, spacing: 24) {
          VStack(alignment: .center, spacing: 10) {
            Text("Tone Atelier")
              .font(.largeTitle.bold())
              .foregroundStyle(.white)

            Text("아이디/비밀번호 로그인과 소셜 로그인 진입점을 먼저 구성합니다.")
              .font(.subheadline)
              .foregroundStyle(.white.opacity(0.62))
              .multilineTextAlignment(.center)
              .frame(maxWidth: .infinity)
              .padding(.horizontal, 4)
          }
          .padding(.top, 24)

          VStack(spacing: 16) {
            LoginTextField(
              title: "아이디",
              placeholder: "아이디를 입력해 주세요",
              text: $store.id
            )

            LoginTextField(
              title: "비밀번호",
              placeholder: "비밀번호를 입력해 주세요",
              text: $store.password,
              isSecure: true
            )
          }

          Button {
            store.send(.loginButtonTapped)
          } label: {
            Text("로그인")
              .font(.body.weight(.semibold))
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity)
              .frame(height: 56)
              .background(
                LinearGradient(
                  colors: [
                    Color(red: 0.27, green: 0.52, blue: 0.96),
                    Color(red: 0.18, green: 0.42, blue: 0.88)
                  ],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                )
              )
              .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
          }
          .buttonStyle(.plain)
          .disabled(store.isEmailLoginInProgress)

          LoginDivider()

          VStack(spacing: 12) {
            SocialLoginButton(provider: .kakao) {
              store.send(.kakaoLoginButtonTapped)
            }
            .disabled(store.isKakaoLoginInProgress)

            SocialLoginButton(provider: .apple) {
              store.send(.appleLoginButtonTapped)
            }
            .disabled(store.isAppleLoginInProgress)
          }

          Spacer(minLength: 24)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
      }
    }
    .navigationTitle("로그인")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(Color(red: 0.03, green: 0.04, blue: 0.06), for: .navigationBar)
    .toolbarBackground(.visible, for: .navigationBar)
    .preferredColorScheme(.dark)
    .alert($store.scope(state: \.alert, action: \.alert))
  }
}

private struct LoginDivider: View {
  var body: some View {
    HStack(spacing: 12) {
      Rectangle()
        .fill(.white.opacity(0.14))
        .frame(height: 1)

      Text("또는")
        .font(.caption.weight(.medium))
        .foregroundStyle(.white.opacity(0.48))

      Rectangle()
        .fill(.white.opacity(0.14))
        .frame(height: 1)
    }
    .padding(.vertical, 2)
  }
}

#Preview {
  NavigationStack {
    LoginView(
      store: Store(initialState: LoginFeature.State()) {
        LoginFeature()
      }
    )
  }
}
