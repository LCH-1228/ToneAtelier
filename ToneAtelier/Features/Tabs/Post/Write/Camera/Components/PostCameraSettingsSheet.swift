//
//  PostCameraSettingsSheet.swift
//  ToneAtelier
//

import ComposableArchitecture
import SwiftUI

struct PostCameraSettingsSheet: View {
  @Bindable var store: StoreOf<PostCameraFeature>

  var body: some View {
    NavigationStack {
      Form {
        Section("저장 대상") {
          Picker(
            "저장 대상",
            selection: Binding(
              get: { store.settings.saveTarget },
              set: { store.send(.saveTargetChanged($0)) }
            )
          ) {
            ForEach(PostCameraSaveTarget.allCases, id: \.self) { target in
              Text(target.displayLabel).tag(target)
            }
          }
          .pickerStyle(.segmented)
        }
      }
      .navigationTitle("카메라 설정")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("완료") { store.send(.settingsSheetDismissed) }
        }
      }
    }
    .presentationDetents([.medium])
    .presentationDragIndicator(.visible)
  }
}
