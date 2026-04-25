//
//  HomeBannerWebView.swift
//  ToneAtelier
//
//  Created by Codex on 4/25/26.
//

import ComposableArchitecture
import SwiftUI

struct HomeBannerWebView: View {
  private let chromeBackground = Color(
    red: 26.0 / 255.0,
    green: 26.0 / 255.0,
    blue: 26.0 / 255.0
  )

  @Bindable var store: StoreOf<HomeBannerWebFeature>

  init(store: StoreOf<HomeBannerWebFeature>) {
    self.store = store
  }

  var body: some View {
    ZStack {
      chromeBackground
        .ignoresSafeArea()

      HomeAttendanceWebView(
        webViewRequest: store.webViewRequest,
        accessToken: store.accessToken,
        onAttendanceCompleted: { count in
          store.send(.attendanceCompleted(count))
        }
      )
    }
    .navigationTitle(store.title)
    .navigationBarTitleDisplayMode(.inline)
    .navigationBarBackButtonHidden(true)
    .toolbar(.visible, for: .navigationBar)
    .toolbarBackground(.visible, for: .navigationBar)
    .toolbarBackground(chromeBackground, for: .navigationBar)
    .toolbarColorScheme(.dark, for: .navigationBar)
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button {
          store.send(.closeButtonTapped)
        } label: {
          Image(systemName: "chevron.left")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
        }
      }
    }
    .alert($store.scope(state: \.alert, action: \.alert))
  }
}
