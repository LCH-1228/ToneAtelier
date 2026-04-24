//
//  AppRootView.swift
//  ToneAtelier
//
//  Created by Codex on 4/23/26.
//

import ComposableArchitecture
import SwiftUI

struct AppRootView: View {
  @Bindable var store: StoreOf<AppRootFeature>

  init(store: StoreOf<AppRootFeature>) {
    self.store = store
  }

  var body: some View {
    Group {
      if store.isSessionLoading {
        AppRootLoadingView()
      } else if store.isAuthenticated {
        MainTabView(
          store: store.scope(state: \.mainTab, action: \.mainTab)
        )
      } else {
        NavigationStack {
          LoginView(
            store: store.scope(state: \.login, action: \.login)
          )
        }
      }
    }
    .task {
      store.send(.task)
    }
  }
}

private struct AppRootLoadingView: View {
  var body: some View {
    ZStack {
      LinearGradient(
        colors: [
          Color(red: 0.03, green: 0.04, blue: 0.06),
          Color(red: 0.07, green: 0.08, blue: 0.12)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()

      VStack(spacing: 16) {
        ProgressView()
          .tint(.white)
          .scaleEffect(1.15)

        Text("세션을 확인하는 중입니다.")
          .font(.footnote.weight(.medium))
          .foregroundStyle(.white.opacity(0.66))
      }
    }
    .preferredColorScheme(.dark)
  }
}

#Preview {
  AppRootView(
    store: Store(initialState: AppRootFeature.State()) {
      AppRootFeature()
    }
  )
}
