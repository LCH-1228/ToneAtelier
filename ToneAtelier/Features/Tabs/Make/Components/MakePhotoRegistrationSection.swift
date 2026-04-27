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
  let isLoading: Bool
  let failureMessage: String?
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

        PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
          Text(registeredPhoto == nil ? "추가하기" : "수정하기")
            .font(HomeTheme.pretendard(size: 16, weight: .medium))
            .foregroundStyle(HomeTheme.gray75)
            .lineLimit(1)
        }
        .buttonStyle(.plain)
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

  @ViewBuilder
  private var photoContent: some View {
    if let registeredPhoto, let image = UIImage(data: registeredPhoto.imageData) {
      MakeRegisteredPhotoView(image: image)
    } else {
      MakeEmptyPhotoSlotView(isLoading: isLoading)
    }
  }

  private func loadImage(from item: PhotosPickerItem) async {
    onPhotoDataLoadStarted()

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
