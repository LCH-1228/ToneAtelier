//
//  ProfileEditView.swift
//  ToneAtelier
//
//  Created by Codex on 5/1/26.
//

import ComposableArchitecture
import PhotosUI
import SwiftUI
import UIKit

struct ProfileEditView: View {
  @Bindable var store: StoreOf<ProfileEditFeature>
  @State private var photoSelection: PhotosPickerItem?

  var body: some View {
    VStack(spacing: 0) {
      header
      ScrollView {
        VStack(spacing: 18) {
          ProfileEditAvatarSection(
            avatarURL: store.avatarURL,
            pendingImageData: store.pendingAvatarImageData,
            photoSelection: $photoSelection
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
            removeAction: { tag in store.send(.removeTagTapped(tag)) }
          )
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 28)
      }
      .scrollIndicators(.hidden)
    }
    .background(AppTheme.background.ignoresSafeArea())
    .toolbar(.hidden, for: .navigationBar)
    .task(id: photoSelection) {
      // PhotosPicker로 새 항목이 선택되면 UIImage로 변환 후 jpeg 강제 인코딩.
      // raw Data 그대로 보내면 HEIC 등 비-jpeg 형식이 mime 불일치로 서버에서 거부될 수 있다.
      guard let item = photoSelection else { return }
      guard
        let data = try? await item.loadTransferable(type: Data.self),
        let image = UIImage(data: data),
        let jpeg = image.jpegData(compressionQuality: 0.8)
      else {
        photoSelection = nil
        return
      }
      store.send(.photoPicked(jpeg))
      photoSelection = nil
    }
    .alert("해시태그 추가", isPresented: $store.isAddingTag) {
      TextField("태그 (#포함)", text: $store.newTagDraft)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
      Button("추가") { store.send(.addTagCommitted) }
      Button("취소", role: .cancel) { store.send(.addTagCancelled) }
    } message: {
      Text("프로필에 추가할 해시태그를 입력해 주세요.")
    }
    .alert($store.scope(state: \.alert, action: \.alert))
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
      .disabled(store.isSaving)
      .accessibilityLabel("뒤로")

      Spacer(minLength: 0)

      Button {
        store.send(.saveButtonTapped)
      } label: {
        ZStack {
          Text("저장")
            .opacity(store.isSaving ? 0 : 1)
          if store.isSaving {
            ProgressView()
              .tint(AppTheme.gray30)
              .controlSize(.small)
          }
        }
        .font(AppTheme.pretendard(size: 13, weight: .bold))
        .foregroundStyle(AppTheme.gray30)
        .padding(.horizontal, 14)
        .frame(minWidth: 56, minHeight: 32)
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
        .accessibilityAddTraits(.isHeader)
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
