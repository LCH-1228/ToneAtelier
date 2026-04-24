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
      if store.isSessionLoading || store.bootstrapFailure != nil {
        AppRootLoadingView(
          failure: store.bootstrapFailure
        ) {
          store.send(.retryBootstrapButtonTapped)
        }
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
  let failure: AppRootFeature.BootstrapFailure?
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
        if let failure {
          Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: 28, weight: .semibold))
            .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.46))

          VStack(spacing: 8) {
            Text(failure.title)
              .font(.headline.weight(.semibold))
              .foregroundStyle(.white)
              .multilineTextAlignment(.center)

            Text(failure.message)
              .font(.footnote.weight(.medium))
              .foregroundStyle(.white.opacity(0.72))
              .multilineTextAlignment(.center)
          }

          Button(action: onRetry) {
            Text("다시 시도")
              .font(.body.weight(.semibold))
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
        } else {
          ProgressView()
            .tint(.white)
            .scaleEffect(1.15)

          Text("세션을 확인하는 중입니다.")
            .font(.footnote.weight(.medium))
            .foregroundStyle(.white.opacity(0.66))
        }
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
