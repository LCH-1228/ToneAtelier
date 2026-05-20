//
//  ProfileEditFeature.swift
//  ToneAtelier
//
//  Created by Codex on 5/1/26.
//

import ComposableArchitecture
import Foundation

// 사진 선택은 PhotosUI(Make 화면 패턴 참조), 저장은 uploadProfileImage → updateMyProfile 직렬 호출.
// 부모(ProfileFeature)는 `delegate(.profileUpdated(_:))` 수신으로 summary를 부분 갱신한다.
@Reducer
struct ProfileEditFeature {
  @Dependency(\.userClient) var userClient

  @ObservableState
  struct State: Equatable {
    var nickname: String = ""
    var email: String = ""
    var name: String = ""
    var phoneNum: String = ""
    var introduction: String = ""
    var hashTags: [String] = []
    var avatarURL: String?
    /// PhotosPicker로 받은 raw Data. 저장 시 multipart 업로드에 사용한다.
    /// PhotosPickerItem 자체는 Equatable 미지원이라 State에 보관하지 않고 View State로만 둔다.
    var pendingAvatarImageData: Data?
    var isSaving = false
    var newTagDraft: String = ""
    /// 해시태그 추가 alert 표시 여부. View가 `$store.isAddingTag`로 직접 바인딩한다.
    var isAddingTag = false
    /// 저장 실패/검증 등 사용자 안내용 alert.
    @Presents var alert: AlertState<Action.Alert>?

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

  /// 저장 성공 시 부모로 전달하는 변경분. ProfileFeature.summary 갱신에 사용한다.
  /// `name`은 본 화면에서 변경 불가이므로 포함하지 않는다.
  struct SavedProfile: Equatable, Sendable {
    var nickname: String
    var introduction: String
    var phoneNum: String
    var hashTags: [String]
    var avatarURL: String?
  }

  enum Action: BindableAction, Sendable {
    case binding(BindingAction<State>)
    case task
    case saveButtonTapped
    case dismissButtonTapped
    case addTagTapped
    case addTagCommitted
    case addTagCancelled
    case removeTagTapped(String)
    case photoPicked(Data?)
    case saveResponse(Result<SavedProfile, Error>)
    case alert(PresentationAction<Alert>)
    case delegate(Delegate)

    enum Alert: Equatable, Sendable {}

    enum Delegate: Equatable, Sendable {
      case profileUpdated(SavedProfile)
      case dismissRequested
    }
  }

  var body: some Reducer<State, Action> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .binding, .task, .alert, .delegate:
        return .none

      case .dismissButtonTapped:
        return .send(.delegate(.dismissRequested))

      case .addTagTapped:
        // 저장 진행 중에는 다른 alert 충돌을 막기 위해 무시.
        guard !state.isSaving else { return .none }
        state.newTagDraft = ""
        state.isAddingTag = true
        return .none

      case .addTagCancelled:
        state.isAddingTag = false
        state.newTagDraft = ""
        return .none

      case .addTagCommitted:
        let normalized = state.newTagDraft
          .trimmingCharacters(in: .whitespacesAndNewlines)
          .replacingOccurrences(of: " ", with: "")
        state.isAddingTag = false
        state.newTagDraft = ""

        guard !normalized.isEmpty else { return .none }
        let stripped = String(normalized.drop(while: { $0 == "#" }))
        guard !stripped.isEmpty else { return .none }
        let formatted = "#\(stripped)"
        if !state.hashTags.contains(formatted) {
          state.hashTags.append(formatted)
        }
        return .none

      case let .removeTagTapped(tag):
        state.hashTags.removeAll { $0 == tag }
        return .none

      case let .photoPicked(data):
        state.pendingAvatarImageData = data
        return .none

      case .saveButtonTapped:
        // 저장 직전 입력 alert가 떠 있으면 alert 충돌 방지를 위해 닫는다.
        guard !state.isSaving, !state.isAddingTag else { return .none }
        return save(into: &state)

      case let .saveResponse(.success(saved)):
        state.isSaving = false
        state.pendingAvatarImageData = nil
        state.avatarURL = saved.avatarURL
        return .send(.delegate(.profileUpdated(saved)))

      case let .saveResponse(.failure(error)):
        state.isSaving = false
        state.alert = AlertState {
          TextState("저장에 실패했어요")
        } actions: {
          ButtonState(role: .cancel) { TextState("확인") }
        } message: {
          TextState(error.userFacingMessage)
        }
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
  }

  /// 사진 변경 → updateMyProfile 직렬 호출. 사진이 없으면 업데이트만 수행.
  /// 첨부 파일명 정책: ASCII safe + short UUID prefix(서버 timestamp suffix 자동 부여).
  private func save(into state: inout State) -> Effect<Action> {
    state.isSaving = true

    let userClient = self.userClient
    let nickname = state.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
    let phoneNum = state.phoneNum.trimmingCharacters(in: .whitespacesAndNewlines)
    let introduction = state.introduction
    let hashTags = state.hashTags
    let pendingImageData = state.pendingAvatarImageData
    let currentAvatarURL = state.avatarURL

    return .run { send in
      await send(.saveResponse(Result {
        var profileImagePath = currentAvatarURL
        if let data = pendingImageData {
          let shortID = UUID().uuidString.prefix(8).lowercased()
          let upload = UploadFile(
            fieldName: "profile",
            fileName: "profile-\(shortID).jpg",
            mimeType: "image/jpeg",
            data: data
          )
          let uploadResponse = try await userClient.uploadProfileImage(upload)
          profileImagePath = uploadResponse.profileImage
        }

        let updateRequest = ProfileRequestDTO(
          nick: nickname.isEmpty ? nil : nickname,
          name: nil,
          introduction: introduction,
          phoneNum: phoneNum.isEmpty ? nil : phoneNum,
          profileImage: profileImagePath,
          hashTags: hashTags
        )
        _ = try await userClient.updateMyProfile(updateRequest)

        return SavedProfile(
          nickname: nickname,
          introduction: introduction,
          phoneNum: phoneNum,
          hashTags: hashTags,
          avatarURL: profileImagePath
        )
      }))
    }
    // cancelInFlight 미사용: uploadProfileImage 성공 후 updateMyProfile 직전 취소 시
    // 서버 이미지만 업로드된 partial state가 발생할 수 있으므로 isSaving 가드로 중복 호출만 차단.
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

private extension Error {
  var userFacingMessage: String {
    if let apiError = self as? APIError {
      switch apiError {
      case let .invalidBaseURL(message),
           let .invalidURL(message),
           let .transport(message),
           let .decoding(message):
        return message

      case .missingAccessToken, .missingRefreshToken:
        return "인증 정보가 없어 프로필을 저장할 수 없어요."

      case let .invalidSession(statusCode):
        return "세션이 유효하지 않습니다. 다시 로그인해 주세요. (\(statusCode))"

      case let .server(statusCode, message, _):
        if let message, !message.isEmpty {
          return message
        }
        return "서버 응답을 처리하지 못했어요. (\(statusCode))"
      }
    }

    return "프로필 저장에 실패했어요. 잠시 후 다시 시도해 주세요."
  }
}
