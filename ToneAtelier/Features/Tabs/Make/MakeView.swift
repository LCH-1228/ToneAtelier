//
//  MakeView.swift
//  ToneAtelier
//
//  Created by Codex on 4/27/26.
//

import ComposableArchitecture
import SwiftUI

struct MakeView: View {
  @Bindable var store: StoreOf<MakeFeature>

  init(store: StoreOf<MakeFeature>) {
    self.store = store
  }

  var body: some View {
    ScrollView(showsIndicators: false) {
      VStack(alignment: .leading, spacing: 0) {
        formSection(title: "필터명") {
          MakeFormField(
            placeholder: "필터 이름을 입력해주세요.",
            text: $store.filterName
          )
        }
        .padding(.top, 0)

        formSection(title: "카테고리") {
          categoryRow
        }
        .padding(.top, 12)

        MakePhotoRegistrationSection(
          registeredPhoto: store.registeredPhoto,
          filterPresets: store.filterPresets,
          isLoading: store.isPhotoLoading,
          failureMessage: store.photoLoadFailureMessage,
          onEditButtonTapped: { store.send(.editButtonTapped) },
          onPhotoFileLoaded: { store.send(.photoFileLoaded($0)) },
          onPhotoDataLoadStarted: { store.send(.photoDataLoadStarted) },
          onPhotoDataLoadFailed: { store.send(.photoDataLoadFailed) }
        )
        .padding(.top, 12)

        formSection(title: "필터 소개") {
          MakeFormField(
            placeholder: "이 필터에 대해 간단하게 소개해주세요.",
            text: $store.filterDescription
          )
        }
        .padding(.top, 2)

        formSection(title: "판매 가격") {
          MakeFormField(
            placeholder: "1,000",
            text: $store.price,
            trailingText: "원"
          )
        }
        .padding(.top, 20)

        if let submissionMessage = store.submissionMessage,
           let submissionStatus = store.submissionStatus {
          Text(submissionMessage)
            .pretendard(.caption1)
            .foregroundStyle(
              submissionStatus == .success
                ? AppTheme.brightTurquoise
                : Color(red: 0.95, green: 0.49, blue: 0.49)
            )
            .padding(.top, 12)
        }
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 36)
    }
    .background(AppTheme.background.ignoresSafeArea())
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(AppTheme.background, for: .navigationBar)
    .toolbarColorScheme(.dark, for: .navigationBar)
    .toolbar {
      ToolbarItem(placement: .principal) {
        Text("MAKE")
          .mulgyeol(.bodyNormal)
          .foregroundStyle(AppTheme.gray60)
      }
      PlainToolbarItem(placement: .topBarTrailing) {
        Button {
          store.send(.saveButtonTapped)
        } label: {
          Group {
            if store.isSubmitting {
              ProgressView()
                .controlSize(.small)
                .tint(AppTheme.gray75)
            } else {
              Image(AppAsset.Make.save)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
                .foregroundStyle(Color.white)
            }
          }
          .frame(width: 44, height: 44)
          .contentShape(.rect)
        }
        .disabled(store.isSubmitting)
        .accessibilityLabel("저장하기")
      }
    }
    .navigationDestination(isPresented: editIsPresented) {
      if let editStore = store.scope(
        state: \.edit,
        action: \.edit
      ) {
        MakeEditView(store: editStore)
      }
    }
    .alert($store.scope(state: \.alert, action: \.alert))
  }

  private var categoryRow: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(MakeCategory.allCases) { category in
          MakeCategoryChip(
            title: category.rawValue,
            isSelected: store.selectedCategory == category
          ) {
            store.send(.categoryTapped(category))
          }
        }
      }
    }
  }

  private var editIsPresented: Binding<Bool> {
    Binding(
      get: {
        store.edit != nil
      },
      set: { isPresented in
        if !isPresented {
          store.send(.editDismissed)
        }
      }
    )
  }

  private func formSection<Content: View>(
    title: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(title)
        .pretendard(.body1)
        .foregroundStyle(AppTheme.gray60)
        .frame(height: 48, alignment: .center)

      content()
    }
  }
}

#Preview {
  MakeView(
    store: Store(initialState: MakeFeature.State()) {
      MakeFeature()
    }
  )
}
