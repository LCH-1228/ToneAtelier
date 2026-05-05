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
    ZStack {
      AppTheme.background.ignoresSafeArea()

      VStack(spacing: 0) {
        headerBar

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
      }
    }
    .toolbar(.hidden, for: .navigationBar)
    .alert($store.scope(state: \.dismissConfirmation, action: \.alert))
    .fullScreenCover(isPresented: locationSelectIsPresented) {
      if let locationStore = store.scope(state: \.locationSelect, action: \.locationSelect) {
        PostLocationSelectView(store: locationStore)
      }
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

  private var headerBar: some View {
    HStack(spacing: 0) {
      Button {
        store.send(.closeTapped)
      } label: {
        Image(systemName: "chevron.left")
          .font(AppTheme.symbol(size: 18, weight: .regular))
          .foregroundStyle(AppTheme.gray60)
          .frame(width: 44, height: 44)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("뒤로")
      .accessibilityIdentifier("post_write_close_button")

      Spacer(minLength: 0)

      Text(store.isEditing ? "EDIT" : "WRITE")
        .mulgyeol(.pageTitle)
        .foregroundStyle(AppTheme.gray60)
        .accessibilityIdentifier("post_write_header_title")

      Spacer(minLength: 0)

      Button {
        store.send(.saveTapped)
      } label: {
        ZStack {
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
        .frame(width: 64, height: 32)
        .background(store.canSave ? AppTheme.brightTurquoise : AppTheme.deepTurquoise)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .disabled(!store.canSave)
      .padding(.trailing, 8)
      .accessibilityLabel("저장하기")
      .accessibilityIdentifier("post_write_save_button")
    }
    .frame(height: 56)
    .padding(.horizontal, 8)
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
