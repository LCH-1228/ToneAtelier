//
//  ProfileEditFeature.swift
//  ToneAtelier
//
//  Created by Codex on 5/1/26.
//

import ComposableArchitecture
import Foundation

// 본 단계는 정적 UI 단계(Stub Feature). API/Dependency 결합은 후속 브랜치(`feat/profile-edit-interaction`)에서 추가.
// `changePhotoTapped`, `saveButtonTapped`, `addTagTapped`, `removeTagTapped`, `dismissButtonTapped`는 모두 noop.
@Reducer
struct ProfileEditFeature {
  @ObservableState
  struct State: Equatable {
    var nickname: String = ""
    var email: String = ""
    var name: String = ""
    var phoneNum: String = ""
    var introduction: String = ""
    var hashTags: [String] = []
    var avatarURL: String?
    // 사진 선택 후 업로드 대기 — 본 단계 미사용. 후속 브랜치에서 PhotosUI 결합.
    var pendingAvatarImageData: Data?
    var isSaving = false
    var errorMessage: String?

    init(
      nickname: String = "",
      email: String = "",
      name: String = "",
      phoneNum: String = "",
      introduction: String = "",
      hashTags: [String] = [],
      avatarURL: String? = nil
    ) {
      self.nickname = nickname
      self.email = email
      self.name = name
      self.phoneNum = phoneNum
      self.introduction = introduction
      self.hashTags = hashTags
      self.avatarURL = avatarURL
    }
  }

  enum Action: BindableAction, Sendable {
    case binding(BindingAction<State>)
    case task
    case saveButtonTapped
    case dismissButtonTapped
    case changePhotoTapped
    case addTagTapped
    case removeTagTapped(Int)
  }

  var body: some Reducer<State, Action> {
    BindingReducer()
    Reduce { _, _ in .none }
  }
}

extension ProfileEditFeature.State {
  static let placeholder = ProfileEditFeature.State(
    nickname: "sesac",
    email: "sesac@sesac.com",
    name: "김새싹",
    phoneNum: "010-1234-1234",
    introduction: "프로필 소개입니다.",
    hashTags: ["#맑음"],
    avatarURL: nil
  )
}
