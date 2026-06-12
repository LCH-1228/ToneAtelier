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
  @Environment(\.scenePhase) private var scenePhase

  init(store: StoreOf<AppRootFeature>) {
    self.store = store
  }

  var body: some View {
    ZStack {
      if let failure = store.bootstrapFailure {
        AppRootLoadingView(failure: failure) {
          store.send(.retryBootstrapButtonTapped)
        }
        .transition(.opacity)
      } else if store.isSessionLoading {
        LaunchScreenView(
          store: store.scope(state: \.launchScreen, action: \.launchScreen)
        )
        .transition(.opacity)
      } else if store.isAuthenticated {
        MainTabView(
          store: store.scope(state: \.mainTab, action: \.mainTab)
        )
        .transition(.opacity)
      } else {
        NavigationStack {
          LoginView(
            store: store.scope(state: \.login, action: \.login)
          )
        }
        .transition(.opacity)
      }
    }
    .animation(.easeInOut(duration: 0.35), value: store.isSessionLoading)
    .animation(.easeInOut(duration: 0.35), value: store.bootstrapFailure != nil)
    .overlay {
      ToastOverlay(center: ToastCenter.shared)
    }
    .task {
      store.send(.task)
    }
    .onChange(of: scenePhase) { _, newPhase in
      if newPhase == .active {
        store.send(.becameActive)
      }
    }
  }
}

private struct AppRootLoadingView: View {
  let failure: AppRootFeature.BootstrapFailure
  let onRetry: () -> Void

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

      VStack(spacing: 18) {
        Image(systemName: "exclamationmark.triangle.fill")
          .font(AppTheme.symbol(size: 28, weight: .semibold))
          .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.46))

        VStack(spacing: 8) {
          Text(failure.title)
            .pretendard(.title1)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)

          Text(failure.message)
            .pretendard(.body3)
            .foregroundStyle(.white.opacity(0.72))
            .multilineTextAlignment(.center)
        }

        Button(action: onRetry) {
          Text("다시 시도")
            .pretendard(.body1)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
              LinearGradient(
                colors: [
                  Color(red: 0.29, green: 0.54, blue: 0.98),
                  Color(red: 0.17, green: 0.38, blue: 0.81)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
      }
      .padding(.horizontal, 28)
      .frame(maxWidth: 320)
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
