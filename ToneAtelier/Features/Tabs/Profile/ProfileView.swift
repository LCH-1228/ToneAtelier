//
//  ProfileView.swift
//  ToneAtelier
//
//  Created by Codex on 5/1/26.
//

import ComposableArchitecture
import SwiftUI

struct ProfileView: View {
  let store: StoreOf<ProfileFeature>

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        ProfileHeaderView {
          store.send(.settingsButtonTapped)
        }

        VStack(alignment: .leading, spacing: 16) {
          ProfileSummaryCard(summary: store.summary)

          ProfileActionRow(
            editAction: { store.send(.editProfileButtonTapped) },
            shopAction: { store.send(.creatorShopButtonTapped) }
          )

          ProfileFeaturedFilterSection(filter: store.featuredFilter) {
            store.send(.featuredFilterTapped)
          }

          ProfileLikedFilterSection(
            filters: store.likedFilters,
            filterAction: { id in
              store.send(.likedFilterTapped(id))
            },
            viewAllAction: {
              store.send(.viewAllLikesTapped)
            }
          )
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, MainTabBarView.Layout.contentInsetHeight + 32)
      }
    }
    .scrollIndicators(.hidden)
    .background(AppTheme.background.ignoresSafeArea())
    .toolbar(.hidden, for: .navigationBar)
  }
}

#Preview {
  NavigationStack {
    ProfileView(
      store: Store(initialState: ProfileFeature.State()) {
        ProfileFeature()
      }
    )
  }
  .preferredColorScheme(.dark)
}
