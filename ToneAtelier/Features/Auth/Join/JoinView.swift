//
//  JoinView.swift
//  ToneAtelier
//
//  Created by Codex on 4/23/26.
//

import ComposableArchitecture
import SwiftUI

struct JoinView: View {
  @Environment(\.dismiss) private var dismiss
  @Bindable var store: StoreOf<JoinFeature>

  init(store: StoreOf<JoinFeature>) {
    self.store = store
  }

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [
          Color(red: 0.03, green: 0.04, blue: 0.06),
          Color(red: 0.08, green: 0.10, blue: 0.14)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()

      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          VStack(alignment: .leading, spacing: 10) {
            Text("회원가입")
              .mulgyeol(.title1)
              .foregroundStyle(.white)

            Text("계정 정보를 먼저 확인하고, 다음 단계에서 프로필을 입력한 뒤 가입을 완료합니다.")
              .pretendard(.body1)
              .foregroundStyle(.white.opacity(0.62))
              .fixedSize(horizontal: false, vertical: true)
          }
          .padding(.top, 24)

          StepProgressView(currentStep: store.step)

          if store.step == .account {
            AuthSectionCard(title: "계정 정보", subtitle: "1 / 2") {
              VStack(spacing: 14) {
                AuthTextField(
                  title: "이메일",
                  placeholder: "name@example.com",
                  text: $store.email,
                  keyboardType: .emailAddress
                )

                ActionCapsuleButton(
                  title: store.isEmailValidationInProgress ? "확인 중..." : "이메일 중복 확인",
                  isEnabled: !store.isEmailValidationInProgress
                ) {
                  store.send(.validateEmailButtonTapped)
                }

                if store.isEmailValidated {
                  Text("현재 이메일은 사용 가능합니다.")
                    .pretendard(.body3)
                    .foregroundStyle(Color(red: 0.45, green: 0.89, blue: 0.72))
                }

                AuthTextField(
                  title: "비밀번호",
                  placeholder: "8자 이상 입력해 주세요",
                  text: $store.password,
                  isSecure: true
                )

                AuthTextField(
                  title: "비밀번호 확인",
                  placeholder: "비밀번호를 다시 입력해 주세요",
                  text: $store.passwordConfirmation,
                  isSecure: true
                )
              }
            }

            Button {
              store.send(.nextButtonTapped)
            } label: {
              PrimaryJoinButtonLabel(title: "다음")
            }
            .buttonStyle(.plain)

            Text("이 단계에서는 로그인 계정을 먼저 확정합니다.")
              .pretendard(.body3)
              .foregroundStyle(.white.opacity(0.42))
              .frame(maxWidth: .infinity, alignment: .center)
              .padding(.bottom, 24)
          } else {
            AuthSectionCard(title: "프로필 정보", subtitle: "2 / 2") {
              VStack(spacing: 14) {
                AuthTextField(
                  title: "닉네임",
                  placeholder: "활동에 사용할 이름",
                  text: $store.nick
                )

                AuthTextField(
                  title: "이름",
                  placeholder: "실명을 입력해 주세요",
                  text: $store.name
                )

                AuthTextField(
                  title: "소개",
                  placeholder: "한 줄 소개를 입력해 주세요",
                  text: $store.introduction
                )

                AuthTextField(
                  title: "전화번호",
                  placeholder: "01012345678",
                  text: $store.phoneNumber,
                  keyboardType: .phonePad
                )

                AuthTextField(
                  title: "해시태그",
                  placeholder: "portrait, editorial, film",
                  text: $store.hashTagsText
                )

                Text("해시태그는 쉼표로 구분합니다.")
                  .pretendard(.body3)
                  .foregroundStyle(.white.opacity(0.48))
                  .frame(maxWidth: .infinity, alignment: .leading)
              }
            }

            HStack(spacing: 12) {
              SecondaryCapsuleButton(title: "이전") {
                store.send(.previousButtonTapped)
              }

              Button {
                store.send(.joinButtonTapped)
              } label: {
                PrimaryJoinButtonLabel(title: store.isJoinInProgress ? "가입 처리 중..." : "회원가입 완료")
              }
              .buttonStyle(.plain)
              .disabled(store.isJoinInProgress)
            }

            Text("프로필 정보는 가입 후에도 수정할 수 있습니다.")
              .pretendard(.body3)
              .foregroundStyle(.white.opacity(0.42))
              .frame(maxWidth: .infinity, alignment: .center)
              .padding(.bottom, 24)
          }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
      }
    }
    .navigationTitle("회원가입")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(Color(red: 0.03, green: 0.04, blue: 0.06), for: .navigationBar)
    .toolbarBackground(.visible, for: .navigationBar)
    .preferredColorScheme(.dark)
    .alert($store.scope(state: \.alert, action: \.alert))
    .onChange(of: store.isJoinCompleted) { _, isJoinCompleted in
      if isJoinCompleted {
        dismiss()
      }
    }
  }
}

private struct StepProgressView: View {
  let currentStep: JoinFeature.Step

  var body: some View {
    HStack(spacing: 12) {
      StepBadge(
        number: 1,
        title: "계정",
        isActive: currentStep == .account,
        isComplete: currentStep == .profile
      )

      Rectangle()
        .fill(.white.opacity(0.12))
        .frame(height: 1)

      StepBadge(
        number: 2,
        title: "프로필",
        isActive: currentStep == .profile,
        isComplete: false
      )
    }
  }
}

private struct StepBadge: View {
  let number: Int
  let title: String
  let isActive: Bool
  let isComplete: Bool

  private var accentColor: Color {
    if isActive || isComplete {
      return Color(red: 0.38, green: 0.68, blue: 0.98)
    }
    return .white.opacity(0.28)
  }

  var body: some View {
    HStack(spacing: 10) {
      ZStack {
        Circle()
          .fill(accentColor)
          .frame(width: 28, height: 28)

        Text(isComplete ? "✓" : "\(number)")
          .pretendard(.body3)
          .foregroundStyle(.white)
      }

      Text(title)
        .pretendard(.body1)
        .foregroundStyle(isActive || isComplete ? .white : .white.opacity(0.46))
    }
  }
}

private struct AuthSectionCard<Content: View>: View {
  let title: String
  let subtitle: String
  let content: Content

  init(
    title: String,
    subtitle: String,
    @ViewBuilder content: () -> Content
  ) {
    self.title = title
    self.subtitle = subtitle
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .pretendard(.body1)
          .foregroundStyle(.white)

        Text(subtitle)
          .pretendard(.caption1)
          .foregroundStyle(.white.opacity(0.48))
      }

      content
    }
    .padding(18)
    .background(.white.opacity(0.06))
    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .stroke(.white.opacity(0.08), lineWidth: 1)
    }
  }
}

private struct PrimaryJoinButtonLabel: View {
  let title: String

  var body: some View {
    HStack {
      Spacer()
      Text(title)
        .pretendard(.body1)
        .foregroundStyle(.white)
      Spacer()
    }
    .frame(maxWidth: .infinity)
    .frame(height: 56)
    .background(
      LinearGradient(
        colors: [
          Color(red: 0.31, green: 0.58, blue: 0.97),
          Color(red: 0.14, green: 0.37, blue: 0.84)
        ],
        startPoint: .leading,
        endPoint: .trailing
      )
    )
    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
  }
}

private struct ActionCapsuleButton: View {
  let title: String
  let isEnabled: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .pretendard(.body1)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 46)
        .background(
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.white.opacity(isEnabled ? 0.13 : 0.06))
        )
        .overlay {
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(.white.opacity(0.12), lineWidth: 1)
        }
    }
    .buttonStyle(.plain)
    .disabled(!isEnabled)
  }
}

private struct SecondaryCapsuleButton: View {
  let title: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .pretendard(.body1)
        .foregroundStyle(.white.opacity(0.86))
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(.white.opacity(0.12), lineWidth: 1)
        }
    }
    .buttonStyle(.plain)
  }
}

#Preview {
  NavigationStack {
    JoinView(
      store: Store(initialState: JoinFeature.State()) {
        JoinFeature()
      }
    )
  }
}
