//
//  PostWriteFeature.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//
//  Pencil node: jmdsy (Post Create / Edit View)
//

import ComposableArchitecture
import Foundation

@Reducer
struct PostWriteFeature {
  @Dependency(\.postClient) private var postClient

  /// 첨부 미디어 한도. 디자인 명세에 맞춰 5개로 고정.
  static let maxAttachments = 5

  enum Mode: Equatable, Sendable {
    case create
    case edit(postID: String)
  }

  /// 화면이 보유한 미디어. 신규로 추가한 항목은 `pending`이고, 업로드 후에는 서버 path 문자열로 변환된다.
  /// edit 모드 진입 시 기존 게시글 path는 `uploaded` 케이스로 들어온다.
  enum AttachmentItem: Equatable, Identifiable, Sendable {
    case pending(id: UUID, fileName: String, mimeType: String, data: Data)
    case uploaded(id: UUID, path: String)

    var id: UUID {
      switch self {
      case let .pending(id, _, _, _): return id
      case let .uploaded(id, _): return id
      }
    }

    var serverPath: String? {
      if case let .uploaded(_, path) = self { return path }
      return nil
    }
  }

  @ObservableState
  struct State: Equatable {
    var mode: Mode = .create
    var category: PostCategory?
    var title: String = ""
    var content: String = ""
    var attachments: [AttachmentItem] = []

    /// 위치는 작성자가 명시적으로 선택한 좌표만 인정한다.
    /// nil이면 저장 시 검증에서 막힌다.
    var location: GeolocationDTO?
    var locationAddress: String?

    var isSubmitting = false
    var errorMessage: String?

    /// 사용자가 닫기 버튼을 눌렀을 때 변경 사항이 있으면 한 번 확인 받는다.
    @Presents var dismissConfirmation: AlertState<Action.Alert>?

    var canSave: Bool {
      guard !isSubmitting else { return false }
      let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
      let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
      return !trimmedTitle.isEmpty
        && !trimmedContent.isEmpty
        && category != nil
        && location != nil
    }

    var attachmentRemainingSlots: Int {
      max(0, PostWriteFeature.maxAttachments - attachments.count)
    }

    var isEditing: Bool {
      if case .edit = mode { return true }
      return false
    }

    /// 신규 작성 진입의 기본 init.
    init() {}

    var locationSelect: PostLocationSelectFeature.State?
  }

  enum Action: BindableAction, Sendable {
    case binding(BindingAction<State>)
    case task
    case categoryTapped(PostCategory)
    case attachmentsAdded([PendingAttachment])
    case attachmentReplaced(at: Int, item: PendingAttachment)
    case attachmentMoved(from: Int, to: Int)
    case attachmentRemoveTapped(UUID)
    case locationCellTapped
    case locationSelect(PostLocationSelectFeature.Action)
    case locationSelectDismissed
    case locationSelected(latitude: Double, longitude: Double, address: String?)
    case saveTapped
    case saveResponse(Result<PostResponseDTO, Error>)
    case closeTapped
    case dismissConfirmed
    case alert(PresentationAction<Alert>)
    case delegate(Delegate)

    enum Alert: Equatable, Sendable {
      case confirmDismiss
    }

    enum Delegate: Equatable, Sendable {
      case dismiss
      case postCreated(PostResponseDTO)
      case postUpdated(PostResponseDTO)
    }
  }

  /// 외부 picker에서 들어오는 신규 첨부 1건의 raw 표현. UploadFile 변환 전 단계.
  struct PendingAttachment: Equatable, Sendable {
    let fileName: String
    let mimeType: String
    let data: Data
  }

  var body: some Reducer<State, Action> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .binding:
        state.errorMessage = nil
        return .none

      case .task:
        return .none

      case let .categoryTapped(category):
        state.category = (state.category == category) ? nil : category
        state.errorMessage = nil
        return .none

      case let .attachmentsAdded(items):
        guard !items.isEmpty else { return .none }
        let remaining = state.attachmentRemainingSlots
        let accepted = items.prefix(remaining)
        for item in accepted {
          state.attachments.append(
            .pending(
              id: UUID(),
              fileName: item.fileName,
              mimeType: item.mimeType,
              data: item.data
            )
          )
        }
        state.errorMessage = nil
        return .none

      case let .attachmentReplaced(at, item):
        guard at >= 0, at < state.attachments.count else { return .none }
        state.attachments[at] = .pending(
          id: UUID(),
          fileName: item.fileName,
          mimeType: item.mimeType,
          data: item.data
        )
        state.errorMessage = nil
        return .none

      case let .attachmentMoved(from, to):
        guard
          from >= 0, from < state.attachments.count,
          to >= 0, to <= state.attachments.count,
          from != to
        else { return .none }
        let item = state.attachments.remove(at: from)
        let target = to > from ? to - 1 : to
        state.attachments.insert(item, at: target)
        return .none

      case let .attachmentRemoveTapped(id):
        state.attachments.removeAll { $0.id == id }
        return .none

      case .locationCellTapped:
        state.locationSelect = PostLocationSelectFeature.State(
          latitude: state.location?.latitude,
          longitude: state.location?.longitude,
          address: state.locationAddress
        )
        return .none

      case let .locationSelect(.delegate(.confirmed(latitude, longitude, address))):
        state.location = GeolocationDTO(longitude: longitude, latitude: latitude)
        state.locationAddress = address
        state.locationSelect = nil
        state.errorMessage = nil
        return .none

      case .locationSelect(.delegate(.dismiss)):
        state.locationSelect = nil
        return .none

      case .locationSelect:
        return .none

      case .locationSelectDismissed:
        state.locationSelect = nil
        return .none

      case let .locationSelected(latitude, longitude, address):
        state.location = GeolocationDTO(longitude: longitude, latitude: latitude)
        state.locationAddress = address
        state.errorMessage = nil
        return .none

      case .saveTapped:
        guard state.canSave else {
          state.errorMessage = Self.canSaveValidationMessage(for: state)
          return .none
        }
        guard let category = state.category, let location = state.location else {
          // canSave 통과했다면 도달하지 않지만 안전장치.
          return .none
        }

        state.isSubmitting = true
        state.errorMessage = nil

        let postClient = postClient
        let mode = state.mode
        let title = state.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let content = state.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let attachments = state.attachments
        let categoryRaw = category.rawValue
        let latitude = location.latitude
        let longitude = location.longitude

        return .run { send in
          do {
            let uploadedPaths = try await uploadAndCollectPaths(
              attachments: attachments,
              postClient: postClient
            )

            switch mode {
            case .create:
              let request = PostRequestDTO(
                category: categoryRaw,
                title: title,
                content: content,
                latitude: latitude,
                longitude: longitude,
                files: uploadedPaths.isEmpty ? nil : uploadedPaths
              )
              let created = try await postClient.create(request)
              await send(.saveResponse(.success(created)))
            case let .edit(postID):
              let request = PostUpdateRequestDTO(
                category: categoryRaw,
                title: title,
                content: content,
                latitude: latitude,
                longitude: longitude,
                files: uploadedPaths.isEmpty ? nil : uploadedPaths
              )
              let updated = try await postClient.update(postID, request)
              await send(.saveResponse(.success(updated)))
            }
          } catch {
            await send(.saveResponse(.failure(error)))
          }
        }
        .cancellable(id: "PostWriteFeature.save", cancelInFlight: true)

      case let .saveResponse(.success(post)):
        state.isSubmitting = false
        state.errorMessage = nil
        switch state.mode {
        case .create:
          return .merge(
            .send(.delegate(.postCreated(post))),
            .send(.delegate(.dismiss))
          )
        case .edit:
          return .merge(
            .send(.delegate(.postUpdated(post))),
            .send(.delegate(.dismiss))
          )
        }

      case let .saveResponse(.failure(error)):
        state.isSubmitting = false
        state.errorMessage = Self.userFacingMessage(for: error)
        return .none

      case .closeTapped:
        if state.isDirty {
          state.dismissConfirmation = AlertState {
            TextState("작성 중인 내용이 있어요")
          } actions: {
            ButtonState(role: .cancel) { TextState("계속 작성") }
            ButtonState(role: .destructive, action: .confirmDismiss) { TextState("나가기") }
          } message: {
            TextState("나가면 입력한 내용이 모두 사라져요.")
          }
          return .none
        }
        return .send(.delegate(.dismiss))

      case .alert(.presented(.confirmDismiss)):
        return .send(.dismissConfirmed)

      case .alert:
        return .none

      case .dismissConfirmed:
        return .send(.delegate(.dismiss))

      case .delegate:
        return .none
      }
    }
    .ifLet(\.$dismissConfirmation, action: \.alert)
    .ifLet(\.locationSelect, action: \.locationSelect) {
      PostLocationSelectFeature()
    }
  }

}

// MARK: - Validation / Error message helpers

private extension PostWriteFeature {
  static func canSaveValidationMessage(for state: State) -> String {
    if state.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return "제목을 입력해 주세요."
    }
    if state.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return "본문을 입력해 주세요."
    }
    if state.category == nil {
      return "카테고리를 선택해 주세요."
    }
    if state.location == nil {
      return "위치를 선택해 주세요."
    }
    return "필수 항목을 확인해 주세요."
  }

  static func userFacingMessage(for error: Error) -> String {
    if let apiError = error as? APIError {
      switch apiError {
      case let .invalidBaseURL(message),
           let .invalidURL(message),
           let .transport(message),
           let .decoding(message):
        return message

      case .missingAccessToken, .missingRefreshToken:
        return "인증 정보가 없어 게시글을 저장할 수 없어요."

      case let .invalidSession(statusCode):
        return "세션이 유효하지 않습니다. 다시 로그인해 주세요. (\(statusCode))"

      case let .server(statusCode, message, _):
        if let message, !message.isEmpty {
          return message
        }
        return "게시글 저장에 실패했어요. (\(statusCode))"
      }
    }
    return "게시글을 저장하지 못했어요. 잠시 후 다시 시도해 주세요."
  }
}

// MARK: - Helpers

private extension PostWriteFeature.State {
  /// 사용자가 의도하지 않은 dismiss로 작성 중인 데이터가 사라지는 것을 막기 위한 가드.
  /// edit 모드는 항상 변경 가능성이 있다고 보고 confirmation을 노출.
  var isDirty: Bool {
    if case .edit = mode { return true }
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
    return !trimmedTitle.isEmpty
      || !trimmedContent.isEmpty
      || category != nil
      || location != nil
      || !attachments.isEmpty
  }
}

/// 첨부 항목 중 pending인 것만 모아 한 번에 업로드하고, 모든 항목의 최종 server path 배열을 만든다.
/// edit 모드에서 기존 uploaded 항목은 추가 업로드 없이 그대로 유지된다.
private func uploadAndCollectPaths(
  attachments: [PostWriteFeature.AttachmentItem],
  postClient: PostClient
) async throws -> [String] {
  let pending = attachments.compactMap { item -> UploadFile? in
    if case let .pending(_, fileName, mimeType, data) = item {
      return UploadFile(
        fieldName: "files",
        fileName: fileName,
        mimeType: mimeType,
        data: data
      )
    }
    return nil
  }

  let uploadedPaths: [String]
  if pending.isEmpty {
    uploadedPaths = []
  } else {
    let response = try await postClient.uploadFiles(pending)
    uploadedPaths = response.files
  }

  // attachments 순서 그대로 새 path를 끼워 넣는다.
  var pendingIterator = uploadedPaths.makeIterator()
  var result: [String] = []
  result.reserveCapacity(attachments.count)
  for item in attachments {
    switch item {
    case .uploaded(_, let path):
      result.append(path)
    case .pending:
      if let next = pendingIterator.next() {
        result.append(next)
      }
    }
  }
  return result
}

// MARK: - Convenience initializers

extension PostWriteFeature.State {
  /// 기존 게시글 편집 진입. 게시글 정보로 초기 폼을 채운다.
  init(post: PostResponseDTO) {
    self.init()
    self.mode = .edit(postID: post.postID)
    self.category = PostCategory(rawValue: post.category)
    self.title = post.title
    self.content = post.content
    self.location = post.geolocation
    self.attachments = post.files.map { path in
      .uploaded(id: UUID(), path: path)
    }
  }

  /// 부모(PostFeature)가 Location Select 결과를 직접 주입할 수 있도록 노출하는 helper.
  /// Tier 3에서 PostLocationSelectFeature가 정식 도입되면 reducer에서 자식 delegate로 직접 흐른다.
  mutating func locationSelected(latitude: Double, longitude: Double, address: String?) {
    self.location = GeolocationDTO(longitude: longitude, latitude: latitude)
    self.locationAddress = address
    self.errorMessage = nil
  }
}
