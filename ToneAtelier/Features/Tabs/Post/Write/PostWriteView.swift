//
//  PostWriteView.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//
//  Pencil node: jmdsy (Post Create / Edit View)
//

import ComposableArchitecture
import SwiftUI

struct PostWriteView: View {
  @Bindable var store: StoreOf<PostWriteFeature>

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        PostWriteMediaPickerView(
          attachments: store.attachments,
          remainingSlots: store.attachmentRemainingSlots,
          onPhotosLoaded: { items in
            store.send(.attachmentsAdded(items))
          },
          onAttachmentReplaced: { index, item in
            store.send(.attachmentReplaced(at: index, item: item))
          },
          onAttachmentMoved: { from, to in
            store.send(.attachmentMoved(from: from, to: to))
          },
          onAttachmentRemove: { id in
            store.send(.attachmentRemoveTapped(id))
          },
          onCameraTapped: {
            store.send(.cameraEntryTapped)
          }
        )
        .padding(.horizontal, 20)
        .accessibilityIdentifier("post_write_media_picker")

        VStack(alignment: .leading, spacing: 8) {
          Text("카테고리 *")
            .pretendard(.captionMeta)
            .foregroundStyle(AppTheme.gray75)
            .padding(.horizontal, 20)

          PostCategorySelectorView(selected: store.category) { category in
            store.send(.categoryTapped(category))
          }
          .padding(.horizontal, 20)
          .accessibilityIdentifier("post_write_category_selector")
        }

        PostWriteBodyEditorView(
          title: $store.title,
          content: $store.content
        )
        .padding(.horizontal, 20)

        PostWriteLocationCellView(
          address: store.locationAddress,
          location: store.location,
          onTap: { store.send(.locationCellTapped) }
        )
        .padding(.horizontal, 20)

        if let message = store.errorMessage {
          Text(message)
            .pretendard(.caption1)
            .foregroundStyle(Color(red: 0.95, green: 0.49, blue: 0.49))
            .padding(.horizontal, 20)
        }
      }
      .padding(.top, 8)
      .padding(.bottom, 40)
    }
    .scrollIndicators(.hidden)
    .background(AppTheme.background.ignoresSafeArea())
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(AppTheme.background, for: .navigationBar)
    .toolbarColorScheme(.dark, for: .navigationBar)
    .toolbar {
      PrincipalToolbarTitle(store.isEditing ? "EDIT" : "WRITE")
      PlainToolbarItem(placement: .topBarTrailing) {
        Button {
          store.send(.saveTapped)
        } label: {
          if store.isSubmitting {
            ProgressView()
              .progressViewStyle(.circular)
              .tint(AppTheme.gray30)
          } else {
            Text("저장")
              .pretendard(.captionBold)
              .foregroundStyle(store.canSave ? AppTheme.gray30 : AppTheme.gray60)
          }
        }
        .disabled(!store.canSave)
        .accessibilityLabel("저장하기")
      }
    }
    .alert($store.scope(state: \.dismissConfirmation, action: \.alert))
    .fullScreenCover(isPresented: locationSelectIsPresented) {
      if let locationStore = store.scope(state: \.locationSelect, action: \.locationSelect) {
        PostLocationSelectView(store: locationStore)
      }
    }
    .fullScreenCover(item: $store.scope(state: \.camera, action: \.camera)) { cameraStore in
      PostCameraView(store: cameraStore)
    }
    .task { store.send(.task) }
  }

  private var locationSelectIsPresented: Binding<Bool> {
    Binding(
      get: { store.locationSelect != nil },
      set: { isPresented in
        if !isPresented {
          store.send(.locationSelectDismissed)
        }
      }
    )
  }
}

#Preview {
  NavigationStack {
    PostWriteView(
      store: Store(initialState: PostWriteFeature.State()) {
        PostWriteFeature()
      }
    )
  }
  .preferredColorScheme(.dark)
}
