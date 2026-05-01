//
//  ProfileEditView.swift
//  ToneAtelier
//
//  Created by Codex on 5/1/26.
//

import ComposableArchitecture
import SwiftUI

struct ProfileEditView: View {
  @Bindable var store: StoreOf<ProfileEditFeature>

  var body: some View {
    VStack(spacing: 0) {
      header
      ScrollView {
        VStack(spacing: 18) {
          ProfileEditAvatarSection(
            avatarURL: store.avatarURL,
            changePhotoAction: { store.send(.changePhotoTapped) }
          )

          VStack(spacing: 12) {
            ProfileEditTextField(label: "닉네임", text: $store.nickname)
            ProfileEditTextField(
              label: "이메일",
              text: .constant(store.email),
              isReadOnly: true
            )
            ProfileEditTextField(
              label: "이름",
              text: .constant(store.name),
              isReadOnly: true
            )
            ProfileEditTextField(label: "전화번호", text: $store.phoneNum)
            ProfileEditTextEditor(label: "소개", text: $store.introduction)
          }

          ProfileEditTagSection(
            tags: store.hashTags,
            addAction: { store.send(.addTagTapped) },
            removeAction: { index in store.send(.removeTagTapped(index)) }
          )
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 28)
      }
      .scrollIndicators(.hidden)
    }
    .background(AppTheme.background.ignoresSafeArea())
    .navigationBarBackButtonHidden(true)
    .toolbar(.hidden, for: .navigationBar)
  }

  private var header: some View {
    HStack(spacing: 0) {
      Button {
        store.send(.dismissButtonTapped)
      } label: {
        Image(systemName: "chevron.left")
          .font(AppTheme.symbol(size: 20, weight: .medium))
          .foregroundStyle(AppTheme.gray60)
          .frame(width: 48, height: 48)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("뒤로")

      Spacer(minLength: 0)

      Button {
        store.send(.saveButtonTapped)
      } label: {
        Text("저장")
          .font(AppTheme.pretendard(size: 13, weight: .bold))
          .foregroundStyle(AppTheme.gray30)
          .padding(.horizontal, 14)
          .frame(height: 32)
          .background(AppTheme.brightTurquoise)
          .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      }
      .buttonStyle(.plain)
      .disabled(store.isSaving)
      .accessibilityLabel("저장")
    }
    .overlay {
      Text("EDIT")
        .font(AppTheme.mulgyeol(size: 20))
        .foregroundStyle(AppTheme.gray60)
    }
    .frame(height: 56)
    .padding(.horizontal, 20)
  }
}

#Preview {
  NavigationStack {
    ProfileEditView(
      store: Store(initialState: .placeholder) {
        ProfileEditFeature()
      }
    )
  }
  .preferredColorScheme(.dark)
}
