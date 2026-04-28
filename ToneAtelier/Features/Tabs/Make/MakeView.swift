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
    ZStack {
      HomeTheme.background.ignoresSafeArea()

      ScrollView(showsIndicators: false) {
        VStack(alignment: .leading, spacing: 0) {
          navigationHeader

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
            onPhotoDataLoaded: { store.send(.photoDataLoaded($0)) },
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
              .font(HomeTheme.pretendard(size: 12, weight: .medium))
              .foregroundStyle(
                submissionStatus == .success
                  ? HomeTheme.brightTurquoise
                  : Color(red: 0.95, green: 0.49, blue: 0.49)
              )
              .padding(.top, 12)
          }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, MainTabBarView.Layout.reservedHeight + 36)
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
    .toolbar(.hidden, for: .navigationBar)
  }

  private var navigationHeader: some View {
    HStack {
      Color.clear
        .frame(width: 48, height: 56)

      Spacer()

      Text("MAKE")
        .font(HomeTheme.mulgyeol(size: 20, weight: .bold))
        .foregroundStyle(HomeTheme.gray60)

      Spacer()

      SharedIconButton(
        accessibilityLabel: "저장하기",
        isDisabled: store.isSubmitting
      ) {
        store.send(.saveButtonTapped)
      } icon: {
        if store.isSubmitting {
          ProgressView()
            .controlSize(.small)
            .tint(HomeTheme.gray75)
            .frame(width: 22, height: 22)
        } else {
          Image(AppAsset.Make.save)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(HomeTheme.gray75)
            .frame(width: 22, height: 22)
        }
      }
    }
    .frame(height: 56)
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
        .font(HomeTheme.pretendard(size: 16, weight: .bold))
        .foregroundStyle(HomeTheme.gray60)
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
