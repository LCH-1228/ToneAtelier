import ComposableArchitecture
import SwiftUI

struct UserProfileView: View {
  @Bindable var store: StoreOf<UserProfileFeature>

  var body: some View {
    content
      .background(AppTheme.background.ignoresSafeArea())
      .navigationBarTitleDisplayMode(.inline)
      .toolbarBackground(AppTheme.background, for: .navigationBar)
      .toolbarColorScheme(.dark, for: .navigationBar)
      .toolbar {
        PrincipalToolbarTitle("PROFILE")
      }
      .alert($store.scope(state: \.alert, action: \.alert))
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
            isCreatingRoom: false,
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
        .padding(.bottom, 32)
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
