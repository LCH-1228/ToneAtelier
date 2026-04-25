//
//  HomeBannerWebView.swift
//  ToneAtelier
//
//  Created by Codex on 4/25/26.
//

import ComposableArchitecture
import SwiftUI

struct HomeBannerWebView: View {
  @Bindable var store: StoreOf<HomeBannerWebFeature>

  init(store: StoreOf<HomeBannerWebFeature>) {
    self.store = store
  }

  var body: some View {
    HomeAttendanceWebView(
      webViewRequest: store.webViewRequest,
      accessToken: store.accessToken,
      onAttendanceCompleted: { count in
        store.send(.attendanceCompleted(count))
      }
    )
    .background(HomeTheme.background.ignoresSafeArea())
    .navigationTitle(store.title)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button("닫기") {
          store.send(.closeButtonTapped)
        }
      }
    }
    .alert($store.scope(state: \.alert, action: \.alert))
  }
}
