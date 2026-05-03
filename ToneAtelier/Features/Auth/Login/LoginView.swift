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
          if let notice = store.notice {
            SessionNoticeBanner(message: notice.message) {
              store.send(.noticeDismissed)
            }
          }

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
              text: $store.id,
              accessibilityID: "login_id_field"
            )

            LoginTextField(
              title: "비밀번호",
              placeholder: "비밀번호를 입력해 주세요",
              text: $store.password,
              isSecure: true,
              accessibilityID: "login_password_field"
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
          .accessibilityIdentifier("login_submit_button")

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

          HStack(spacing: 6) {
            Text("계정이 아직 없으신가요?")
              .font(.footnote)
              .foregroundStyle(.white.opacity(0.5))

            NavigationLink {
              JoinView(
                store: Store(initialState: JoinFeature.State()) {
                  JoinFeature()
                }
              )
            } label: {
              Text("회원가입")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
            }
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

private struct SessionNoticeBanner: View {
  let message: String
  let onDismiss: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text("세션 안내")
          .font(.caption.weight(.semibold))
          .foregroundStyle(Color(red: 0.58, green: 0.77, blue: 1.0))

        Text(message)
          .font(.footnote)
          .foregroundStyle(.white.opacity(0.88))
          .multilineTextAlignment(.leading)
      }

      Spacer(minLength: 0)

      Button(action: onDismiss) {
        Image(systemName: "xmark")
          .font(.caption.weight(.bold))
          .foregroundStyle(.white.opacity(0.7))
          .frame(width: 28, height: 28)
          .background(.white.opacity(0.08))
          .clipShape(Circle())
      }
      .buttonStyle(.plain)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(
          LinearGradient(
            colors: [
              Color(red: 0.08, green: 0.17, blue: 0.31),
              Color(red: 0.05, green: 0.1, blue: 0.19)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
    )
    .overlay(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .stroke(Color.white.opacity(0.08), lineWidth: 1)
    )
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
