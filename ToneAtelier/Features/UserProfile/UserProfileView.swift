import ComposableArchitecture
import SwiftUI

struct UserProfileView: View {
  @Bindable var store: StoreOf<UserProfileFeature>
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ZStack {
      AppTheme.background.ignoresSafeArea()

      VStack(spacing: 0) {
        UserProfileNavigationHeader(backAction: { dismiss() })
        content
      }
    }
    .toolbar(.hidden, for: .navigationBar)
    .alert($store.scope(state: \.alert, action: \.alert))
    .overlay {
      if store.isCreatingRoom {
        creatingOverlay
      }
    }
    .task { await store.send(.task).finish() }
  }

  @ViewBuilder
  private var content: some View {
    if store.isLoading && store.summary == nil {
      loadingView
    } else if let errorMessage = store.errorMessage, store.summary == nil {
      errorView(message: errorMessage)
    } else {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          ProfileSummaryCard(summary: displaySummary)

          UserProfileActionRow(
            isCreatingRoom: store.isCreatingRoom,
            messageAction: { store.send(.messageButtonTapped) },
            storeAction: { store.send(.storeButtonTapped) }
          )

          if let featured = store.featuredFilter {
            VStack(alignment: .leading, spacing: 10) {
              Text("대표 필터")
                .pretendard(.body1)
                .foregroundStyle(AppTheme.gray60)
              UserProfileFeaturedFilterCard(filter: featured) {
                store.send(.featuredFilterTapped)
              }
            }
          }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, MainTabBarView.Layout.contentInsetHeight + 32)
      }
      .scrollIndicators(.hidden)
    }
  }

  private var displaySummary: ProfileSummary {
    store.summary ?? ProfileSummary(
      id: store.userID,
      name: store.initialNick,
      nickname: store.initialNick,
      bio: store.initialIntroduction ?? "",
      avatarURL: store.initialProfileImage,
      email: "",
      phoneNum: nil,
      hashTags: [],
      stats: [
        ProfileStat(value: "0", label: "FILTER"),
        ProfileStat(value: "0", label: "POSTS")
      ]
    )
  }

  private var loadingView: some View {
    VStack(spacing: 14) {
      ProgressView().tint(AppTheme.gray45)
      Text("프로필을 불러오는 중...")
        .pretendard(.body2)
        .foregroundStyle(AppTheme.gray60)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func errorView(message: String) -> some View {
    VStack(spacing: 12) {
      Text(message)
        .pretendard(.body2)
        .foregroundStyle(AppTheme.gray60)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 32)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var creatingOverlay: some View {
    ZStack {
      Color.black.opacity(0.4).ignoresSafeArea()
      VStack(spacing: 12) {
        ProgressView().progressViewStyle(.circular).tint(.white)
        Text("채팅방을 만드는 중...")
          .pretendard(.body2)
          .foregroundStyle(.white)
      }
      .padding(.vertical, 18)
      .padding(.horizontal, 24)
      .background(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(AppTheme.deepTurquoise.opacity(0.95))
      )
    }
    .transition(.opacity)
  }
}

#Preview {
  NavigationStack {
    UserProfileView(
      store: Store(
        initialState: UserProfileFeature.State(
          userID: "preview",
          initialNick: "윤새싹",
          initialIntroduction: "맑고 투명한 자연광 톤",
          initialProfileImage: nil
        )
      ) {
        UserProfileFeature()
      }
    )
  }
  .preferredColorScheme(.dark)
}
