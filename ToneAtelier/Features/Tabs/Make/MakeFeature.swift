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
  @ObservableState
  struct State: Equatable {
    var edit: MakeEditFeature.State?
    var filterName = ""
    var selectedCategory = MakeCategory.people
    var registeredPhoto: RegisteredPhoto?
    var filterDescription = ""
    var price = "1,000"
    var isPhotoLoading = false
    var photoLoadFailureMessage: String?
  }

  struct RegisteredPhoto: Equatable, Sendable {
    let imageData: Data
    let exif: ExifInfo
  }

  struct ExifInfo: Equatable, Sendable {
    let deviceLine: String
    let cameraLine: String
    let fileLine: String
    let locationLine: String?
  }

  enum Action: BindableAction, Equatable, Sendable {
    case binding(BindingAction<State>)
    case categoryTapped(MakeCategory)
    case edit(MakeEditFeature.Action)
    case editButtonTapped
    case editDismissed
    case photoDataLoadFailed
    case photoDataLoadStarted
    case photoDataLoaded(Data)
  }

  var body: some Reducer<State, Action> {
    BindingReducer()

    Reduce { state, action in
      switch action {
      case .binding:
        return .none

      case let .categoryTapped(category):
        state.selectedCategory = category
        return .none

      case .edit:
        return .none

      case .editButtonTapped:
        guard state.registeredPhoto != nil else {
          return .none
        }
        state.edit = MakeEditFeature.State()
        return .none

      case .editDismissed:
        state.edit = nil
        return .none

      case .photoDataLoadFailed:
        state.isPhotoLoading = false
        state.photoLoadFailureMessage = "사진을 불러오지 못했어요."
        return .none

      case .photoDataLoadStarted:
        state.isPhotoLoading = true
        state.photoLoadFailureMessage = nil
        return .none

      case let .photoDataLoaded(data):
        state.isPhotoLoading = false
        state.photoLoadFailureMessage = nil
        state.registeredPhoto = MakePhotoMetadataExtractor.makeRegisteredPhoto(from: data)
        return .none
      }
    }
    .ifLet(\.edit, action: \.edit) {
      MakeEditFeature()
    }
  }
}
