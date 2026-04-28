//
//  MakePhotoRegistrationSection.swift
//  ToneAtelier
//
//  Created by Codex on 4/27/26.
//

import PhotosUI
import SwiftUI
import UIKit

struct MakePhotoRegistrationSection: View {
  let registeredPhoto: MakeFeature.RegisteredPhoto?
  let filterPresets: [MakeFilterPreset]
  let isLoading: Bool
  let failureMessage: String?
  let onEditButtonTapped: () -> Void
  let onPhotoDataLoaded: (Data) -> Void
  let onPhotoDataLoadStarted: () -> Void
  let onPhotoDataLoadFailed: () -> Void

  @State private var selectedItem: PhotosPickerItem?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("대표 사진 등록")
          .font(HomeTheme.pretendard(size: 16, weight: .bold))
          .foregroundStyle(HomeTheme.gray60)
          .lineLimit(1)

        Spacer()

        if registeredPhoto == nil {
          PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
            actionButtonTitle("추가하기")
          }
          .buttonStyle(.plain)
        } else {
          Button(action: onEditButtonTapped) {
            actionButtonTitle("수정하기")
          }
          .buttonStyle(.plain)
        }
      }
      .frame(height: 48)

      PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
        photoContent
      }
      .buttonStyle(.plain)

      if let registeredPhoto {
        MakeExifInfoCard(photo: registeredPhoto)
          .frame(height: 120)
          .clipped()
      }

      MakeFilterPresetSection(presets: filterPresets)

      if let failureMessage {
        Text(failureMessage)
          .font(HomeTheme.pretendard(size: 12, weight: .medium))
          .foregroundStyle(Color(red: 0.95, green: 0.49, blue: 0.49))
      }
    }
    .task(id: selectedItem) {
      guard let selectedItem else { return }
      await loadImage(from: selectedItem)
    }
  }

  private func actionButtonTitle(_ title: String) -> some View {
    Text(title)
      .font(HomeTheme.pretendard(size: 16, weight: .medium))
      .foregroundStyle(HomeTheme.gray75)
      .lineLimit(1)
  }

  @ViewBuilder
  private var photoContent: some View {
    if let registeredPhoto, let image = UIImage(data: registeredPhoto.previewImageData) {
      MakeRegisteredPhotoView(image: image)
    } else {
      MakeEmptyPhotoSlotView(isLoading: isLoading)
    }
  }

  private func loadImage(from item: PhotosPickerItem) async {
    onPhotoDataLoadStarted()
    defer {
      selectedItem = nil
    }

    do {
      guard let data = try await item.loadTransferable(type: Data.self) else {
        onPhotoDataLoadFailed()
        return
      }

      onPhotoDataLoaded(data)
    } catch {
      onPhotoDataLoadFailed()
    }
  }
}

private struct MakeFilterPresetSection: View {
  let presets: [MakeFilterPreset]

  private let columns = Array(
    repeating: GridItem(.fixed(32), spacing: 20),
    count: 6
  )

  var body: some View {
    VStack(spacing: 0) {
      HomeDetailSectionHeader(
        leading: "Filter Presets",
        trailing: "LUT"
      )

      LazyVGrid(columns: columns, spacing: 13) {
        ForEach(presets) { preset in
          VStack(spacing: 4) {
            Image(preset.assetName)
              .renderingMode(.template)
              .resizable()
              .scaledToFit()
              .foregroundStyle(preset.isEdited ? HomeTheme.gray30 : HomeTheme.gray75)
              .frame(width: 32, height: 32)

            Text(preset.value)
              .font(HomeTheme.pretendard(size: 14, weight: .bold))
              .foregroundStyle(preset.isEdited ? HomeTheme.gray30 : HomeTheme.gray75)
              .lineLimit(1)
              .minimumScaleFactor(0.75)
              .frame(width: 36)
          }
          .frame(width: 44, height: 52)
        }
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 20)
      .frame(height: 162)
      .frame(maxWidth: .infinity)
      .background(HomeTheme.blackTurquoise)
      .clipShape(
        UnevenRoundedRectangle(
          topLeadingRadius: 0,
          bottomLeadingRadius: 8,
          bottomTrailingRadius: 8,
          topTrailingRadius: 0,
          style: .continuous
        )
      )
    }
  }
}

struct MakeFilterPreset: Identifiable, Equatable {
  let id: String
  let assetName: String
  let value: String
  let isEdited: Bool
}

extension MakeFilterValues {
  var makeFilterPresets: [MakeFilterPreset] {
    MakeFilterParameter.allCases.map { parameter in
      let value = value(for: parameter)

      return MakeFilterPreset(
        id: parameter.presetID,
        assetName: parameter.assetName,
        value: parameter.displayValue(value),
        isEdited: parameter.isEdited(value: value)
      )
    }
  }
}

private extension MakeFilterParameter {
  var presetID: String {
    switch self {
    case .brightness:
      return "brightness"
    case .exposure:
      return "exposure"
    case .contrast:
      return "contrast"
    case .saturation:
      return "saturation"
    case .sharpness:
      return "sharpness"
    case .blur:
      return "blur"
    case .vignette:
      return "vignette"
    case .noiseReduction:
      return "noise_reduction"
    case .highlights:
      return "highlights"
    case .shadows:
      return "shadows"
    case .temperature:
      return "temperature"
    case .blackPoint:
      return "black_point"
    }
  }
}
