//
//  MakeFeature.swift
//  ToneAtelier
//
//  Created by Codex on 4/27/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct MakeFeature {
  @Dependency(\.filterClient) private var filterClient

  @ObservableState
  struct State: Equatable {
    @Presents var alert: AlertState<Action.Alert>?
    var edit: MakeEditFeature.State?
    var filterName = ""
    var selectedCategory = MakeCategory.people
    var registeredPhoto: RegisteredPhoto?
    var filterValues = MakeFilterValues()
    var filterPresets = MakeFilterValues().makeFilterPresets
    var filterDescription = ""
    var price = "1,000"
    var isPhotoLoading = false
    var photoLoadFailureMessage: String?
    var isSubmitting = false
    var submissionStatus: SubmissionStatus?
    var submissionMessage: String?

    mutating func setFilterValues(_ filterValues: MakeFilterValues) {
      self.filterValues = filterValues
      self.filterPresets = filterValues.makeFilterPresets
    }
  }

  struct RegisteredPhoto: Equatable, Sendable {
    let imageFileURL: URL
    let previewImageData: Data
    let thumbnailImageData: Data
    let exif: ExifInfo
    let metadata: MakePhotoMetadata
  }

  struct ExifInfo: Equatable, Sendable {
    let deviceLine: String
    let cameraLine: String
    let fileLine: String
    let locationLine: String?
  }

  enum SubmissionStatus: Equatable, Sendable {
    case success
    case failure
  }

  enum Action: BindableAction, Equatable, Sendable {
    case alert(PresentationAction<Alert>)
    case binding(BindingAction<State>)
    case categoryTapped(MakeCategory)
    case edit(MakeEditFeature.Action)
    case editButtonTapped
    case editDismissed
    case filterCreateFailed(String)
    case filterCreateSucceeded
    case photoDataLoadFailed
    case photoDataLoadStarted
    case photoFileLoaded(URL)
    case registeredPhotoLoaded(RegisteredPhoto)
    case registeredPhotoLoadFailed(String, URL)
    case saveButtonTapped

    enum Alert: Equatable, Sendable {}
  }

  var body: some Reducer<State, Action> {
    BindingReducer()

    Reduce { state, action in
      switch action {
      case .alert:
        return .none

      case .binding:
        state.clearSubmissionFeedback()
        return .none

      case let .categoryTapped(category):
        state.selectedCategory = category
        state.clearSubmissionFeedback()
        return .none

      case .edit(.delegate(.canceled)):
        state.edit = nil
        return .none

      case let .edit(.delegate(.saved(filterValues))):
        state.setFilterValues(filterValues)
        state.edit = nil
        return .none

      case .edit:
        return .none

      case .editButtonTapped:
        guard let registeredPhoto = state.registeredPhoto else {
          return .none
        }
        state.edit = MakeEditFeature.State(
          registeredPhoto: registeredPhoto,
          filterValues: state.filterValues
        )
        return .none

      case .editDismissed:
        state.edit = nil
        return .none

      case let .filterCreateFailed(message):
        state.isSubmitting = false
        state.submissionStatus = .failure
        state.submissionMessage = message
        return .none

      case .filterCreateSucceeded:
        let imageFileURL = state.registeredPhoto?.imageFileURL
        state.resetFormAfterSuccessfulCreate()
        state.alert = AlertState {
          TextState("저장 완료")
        } actions: {
          ButtonState(role: .cancel) {
            TextState("확인")
          }
        } message: {
          TextState("필터가 저장됐어요.")
        }
        return .run { _ in
          MakePhotoFileCleaner.removeFileIfNeeded(at: imageFileURL)
        }

      case .photoDataLoadFailed:
        state.isPhotoLoading = false
        state.photoLoadFailureMessage = "사진을 불러오지 못했어요."
        state.clearSubmissionFeedback()
        return .none

      case .photoDataLoadStarted:
        state.isPhotoLoading = true
        state.photoLoadFailureMessage = nil
        state.clearSubmissionFeedback()
        return .none

      case let .photoFileLoaded(url):
        state.photoLoadFailureMessage = nil
        return .run { send in
          do {
            try Task.checkCancellation()
            let registeredPhoto = try MakePhotoMetadataExtractor.makeRegisteredPhoto(from: url)
            try Task.checkCancellation()
            await send(.registeredPhotoLoaded(registeredPhoto))
          } catch is CancellationError {
            MakePhotoFileCleaner.removeFileIfNeeded(at: url)
          } catch {
            await send(.registeredPhotoLoadFailed(error.makePhotoLoadMessage, url))
          }
        }
        .cancellable(id: "MakeFeature.photoLoad", cancelInFlight: true)

      case let .registeredPhotoLoaded(registeredPhoto):
        let previousImageFileURL = state.registeredPhoto?.imageFileURL
        state.isPhotoLoading = false
        state.photoLoadFailureMessage = nil
        state.registeredPhoto = registeredPhoto
        state.setFilterValues(.default)
        state.clearSubmissionFeedback()
        return .run { _ in
          MakePhotoFileCleaner.removeFileIfNeeded(at: previousImageFileURL)
        }

      case let .registeredPhotoLoadFailed(message, url):
        state.isPhotoLoading = false
        state.registeredPhoto = nil
        state.photoLoadFailureMessage = message
        state.setFilterValues(.default)
        state.clearSubmissionFeedback()
        return .run { _ in
          MakePhotoFileCleaner.removeFileIfNeeded(at: url)
        }

      case .saveButtonTapped:
        guard !state.isSubmitting else { return .none }

        let draft: MakeSubmissionDraft
        do {
          draft = try state.makeSubmissionDraft()
        } catch {
          state.submissionStatus = .failure
          state.submissionMessage = error.makeSubmissionMessage
          return .none
        }

        state.isSubmitting = true
        state.submissionStatus = nil
        state.submissionMessage = nil

        let filterClient = filterClient
        return .run { send in
          do {
            let previewData = try MakeFilterUploadFileFactory.makePreviewData(from: draft.imageFileURL)
            let uploadFiles = await MakeFilterUploadFileFactory.makeUploadFiles(from: previewData)
            let uploadedFilesResponse = try await filterClient.uploadFiles(uploadFiles)

            guard uploadedFilesResponse.files.count == uploadFiles.count else {
              throw MakeSubmissionError.invalidUploadResponse
            }

            _ = try await filterClient.create(
              draft.createFilterRequest(files: uploadedFilesResponse.files)
            )
            await send(.filterCreateSucceeded)
          } catch {
            await send(.filterCreateFailed(error.makeSubmissionMessage))
          }
        }
      }
    }
    .ifLet(\.$alert, action: \.alert)
    .ifLet(\.edit, action: \.edit) {
      MakeEditFeature()
    }
  }
}

private struct MakeSubmissionDraft: Sendable {
  let title: String
  let category: String
  let price: Int?
  let description: String
  let imageFileURL: URL
  let photoMetadata: MakePhotoMetadata
  let filterValues: MakeFilterValues

  func createFilterRequest(files: [String]) -> CreateFilterRequest {
    CreateFilterRequest(
      category: category,
      title: title,
      price: price,
      description: description,
      files: files,
      photo_metadata: photoMetadata.jsonValue,
      filter_values: filterValues.jsonValue
    )
  }
}

private enum MakeSubmissionError: LocalizedError {
  case emptyTitle
  case missingPhoto
  case invalidPrice
  case invalidUploadResponse

  var errorDescription: String? {
    switch self {
    case .emptyTitle:
      return "필터명을 입력해주세요."
    case .missingPhoto:
      return "대표 사진을 등록해주세요."
    case .invalidPrice:
      return "판매 가격은 숫자로 입력해주세요."
    case .invalidUploadResponse:
      return "업로드된 파일 정보를 확인할 수 없어요."
    }
  }
}

private extension MakeFeature.State {
  mutating func clearSubmissionFeedback() {
    guard !isSubmitting else { return }
    submissionStatus = nil
    submissionMessage = nil
  }

  mutating func resetFormAfterSuccessfulCreate() {
    edit = nil
    filterName = ""
    selectedCategory = .people
    registeredPhoto = nil
    setFilterValues(.default)
    filterDescription = ""
    price = "1,000"
    isPhotoLoading = false
    photoLoadFailureMessage = nil
    isSubmitting = false
    submissionStatus = nil
    submissionMessage = nil
  }

  func makeSubmissionDraft() throws -> MakeSubmissionDraft {
    let title = filterName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty else {
      throw MakeSubmissionError.emptyTitle
    }

    guard let registeredPhoto else {
      throw MakeSubmissionError.missingPhoto
    }

    return MakeSubmissionDraft(
      title: title,
      category: selectedCategory.rawValue,
      price: try parsedPrice(),
      description: filterDescription.trimmingCharacters(in: .whitespacesAndNewlines),
      imageFileURL: registeredPhoto.imageFileURL,
      photoMetadata: registeredPhoto.metadata,
      filterValues: filterValues
    )
  }

  private func parsedPrice() throws -> Int? {
    let trimmedPrice = price.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedPrice.isEmpty else { return nil }

    let digits = String(trimmedPrice.filter(\.isNumber))
    guard !digits.isEmpty, let parsedPrice = Int(digits) else {
      throw MakeSubmissionError.invalidPrice
    }

    return parsedPrice
  }
}

private extension Error {
  nonisolated var makePhotoLoadMessage: String {
    if let localizedError = self as? LocalizedError,
       let errorDescription = localizedError.errorDescription {
      return errorDescription
    }

    return "사진을 불러오지 못했어요."
  }

  nonisolated var makeSubmissionMessage: String {
    if let apiError = self as? APIError {
      return apiError.errorDescription ?? "필터를 저장하지 못했어요."
    }

    if let localizedError = self as? LocalizedError,
       let errorDescription = localizedError.errorDescription {
      return errorDescription
    }

    return "필터를 저장하지 못했어요. 잠시 후 다시 시도해주세요."
  }
}
