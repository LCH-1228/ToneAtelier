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
              onAttachmentRemove: { id in
                store.send(.attachmentRemoveTapped(id))
              }
            )
            .padding(.horizontal, 20)
            .accessibilityIdentifier("post_write_media_picker")

            VStack(alignment: .leading, spacing: 8) {
              Text("카테고리 *")
                .font(AppTheme.pretendard(size: 11, weight: .bold))
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
                .font(AppTheme.pretendard(size: 12, weight: .medium))
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
    .task { store.send(.task) }
  }

  private var headerBar: some View {
    HStack(spacing: 0) {
      Button {
        store.send(.closeTapped)
      } label: {
        Image(systemName: "xmark")
          .font(AppTheme.symbol(size: 18, weight: .regular))
          .foregroundStyle(AppTheme.gray60)
          .frame(width: 44, height: 44)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("닫기")
      .accessibilityIdentifier("post_write_close_button")

      Spacer(minLength: 0)

      Text(store.isEditing ? "EDIT" : "WRITE")
        .font(AppTheme.mulgyeol(size: 21, weight: .bold))
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
              .font(AppTheme.pretendard(size: 12, weight: .bold))
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
