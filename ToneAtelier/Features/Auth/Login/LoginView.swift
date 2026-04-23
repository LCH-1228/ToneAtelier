//
//  LoginView.swift
//  ToneAtelier
//
//  Created by Codex on 4/23/26.
//

import ComposableArchitecture
import SwiftUI

struct LoginView: View {
  @Dependency(\.kakaoAuthClient) private var kakaoAuthClient
  @Dependency(\.userClient) private var userClient

  @State private var id = ""
  @State private var password = ""
  @State private var alertMessage = ""
  @State private var isShowingAlert = false
  @State private var isKakaoLoginInProgress = false

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
              text: $id
            )

            LoginTextField(
              title: "비밀번호",
              placeholder: "비밀번호를 입력해 주세요",
              text: $password,
              isSecure: true
            )
          }

          Button {
            showAlert("다음 단계에서 이메일 로그인 로직을 연결합니다.")
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

          LoginDivider()

          VStack(spacing: 12) {
            SocialLoginButton(provider: .kakao) {
              Task {
                await loginWithKakao()
              }
            }
            .disabled(isKakaoLoginInProgress)

            SocialLoginButton(provider: .apple) {
              showAlert("다음 단계에서 Apple 로그인 로직을 연결합니다.")
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
    .alert("알림", isPresented: $isShowingAlert) {
      Button("확인", role: .cancel) {}
    } message: {
      Text(alertMessage)
    }
  }

  private func loginWithKakao() async {
    guard !isKakaoLoginInProgress else { return }

    isKakaoLoginInProgress = true

    defer {
      isKakaoLoginInProgress = false
    }

    do {
      let oauthToken = try await kakaoAuthClient.login()
      let response = try await userClient.loginKakao(
        KakaoLoginRequest(
          oauthToken: oauthToken,
          deviceToken: nil
        )
      )
      showAlert("\(response.nick)님, 카카오 로그인에 성공했습니다.")
    } catch {
      showAlert("카카오 로그인 실패: \(error.localizedDescription)")
    }
  }

  private func showAlert(_ message: String) {
    alertMessage = message
    isShowingAlert = true
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
    LoginView()
  }
}
