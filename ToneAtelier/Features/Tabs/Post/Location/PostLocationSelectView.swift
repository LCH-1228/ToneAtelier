//
//  PostLocationSelectView.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//
//  Pencil node: lullK (Post Location Select View)
//

import ComposableArchitecture
import CoreLocation
import SwiftUI

struct PostLocationSelectView: View {
  @Bindable var store: StoreOf<PostLocationSelectFeature>
  @FocusState private var isQueryFocused: Bool

  var body: some View {
    ZStack {
      AppTheme.background.ignoresSafeArea()

      VStack(spacing: 0) {
        headerBar
        searchBox
          .padding(.horizontal, 20)
          .padding(.top, 8)

        ScrollView {
          VStack(spacing: 16) {
            mapSection
              .frame(height: 320)

            PostLocationSelectedCardView(
              address: store.selectedAddress,
              latitude: store.selectedLatitude,
              longitude: store.selectedLongitude
            )

            if let message = store.errorMessage {
              Text(message)
                .pretendard(.captionBold)
                .foregroundStyle(Color(red: 0.95, green: 0.49, blue: 0.49))
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            PostLocationRecentListView(
              recents: store.recents,
              onTap: { recent in
                store.send(.recentTapped(recent))
              }
            )

            Spacer(minLength: 24)
          }
          .padding(.horizontal, 20)
          .padding(.top, 16)
          .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)

        confirmBar
      }
    }
    .task { store.send(.task) }
  }

  private var headerBar: some View {
    HStack(spacing: 0) {
      Button {
        store.send(.closeTapped)
      } label: {
        Image(systemName: "chevron.left")
          .font(AppTheme.symbol(size: 18, weight: .regular))
          .foregroundStyle(AppTheme.gray60)
          .frame(width: 44, height: 44)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("뒤로")
      .accessibilityIdentifier("post_location_back_button")

      Spacer(minLength: 0)

      Text("LOCATION")
        .mulgyeol(.pageTitle)
        .foregroundStyle(AppTheme.gray60)
        .accessibilityIdentifier("post_location_header_title")

      Spacer(minLength: 0)

      Color.clear.frame(width: 44, height: 44)
    }
    .frame(height: 56)
    .padding(.horizontal, 8)
  }

  private var searchBox: some View {
    HStack(spacing: 8) {
      Image(systemName: "magnifyingglass")
        .font(AppTheme.symbol(size: 16, weight: .regular))
        .foregroundStyle(AppTheme.gray60)

      TextField(
        "주소 또는 장소 검색",
        text: $store.query
      )
      .pretendard(.body3Bold)
      .foregroundStyle(AppTheme.gray30)
      .tint(AppTheme.gray30)
      .submitLabel(.search)
      .focused($isQueryFocused)
      .onSubmit {
        store.send(.querySubmitted)
      }
      .accessibilityIdentifier("post_location_query_field")

      if store.isResolving {
        ProgressView()
          .controlSize(.small)
          .tint(AppTheme.gray45)
      }
    }
    .padding(.horizontal, 14)
    .frame(height: 48)
    .background(AppTheme.blackTurquoise)
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
  }

  private var mapSection: some View {
    ZStack(alignment: .bottomTrailing) {
      PostLocationMapView(
        coordinate: pinCoordinate,
        onCoordinateChanged: { coordinate in
          store.send(
            .pinCoordinateChanged(
              latitude: coordinate.latitude,
              longitude: coordinate.longitude
            )
          )
        }
      )
      .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

      Button {
        store.send(.useCurrentLocationTapped)
      } label: {
        HStack(spacing: 6) {
          Image(systemName: "location.fill")
            .font(AppTheme.symbol(size: 14, weight: .regular))
            .foregroundStyle(AppTheme.gray30)
          Text("현재 위치")
            .pretendard(.captionBold)
            .foregroundStyle(AppTheme.gray30)
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(AppTheme.background.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
      }
      .buttonStyle(.plain)
      .accessibilityLabel("현재 위치로 이동")
      .padding(12)
    }
  }

  private var confirmBar: some View {
    Button {
      store.send(.confirmTapped)
    } label: {
      Text("이 위치로 선택")
        .pretendard(.body2)
        .foregroundStyle(AppTheme.gray30)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(store.canConfirm ? AppTheme.brightTurquoise : AppTheme.deepTurquoise)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
    .buttonStyle(.plain)
    .disabled(!store.canConfirm)
    .padding(.horizontal, 20)
    .padding(.bottom, 24)
    .accessibilityIdentifier("post_location_confirm_button")
  }

  private var pinCoordinate: CLLocationCoordinate2D? {
    guard
      let latitude = store.selectedLatitude,
      let longitude = store.selectedLongitude
    else {
      return nil
    }
    return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
  }
}

#Preview {
  NavigationStack {
    PostLocationSelectView(
      store: Store(initialState: PostLocationSelectFeature.State()) {
        PostLocationSelectFeature()
      }
    )
  }
  .preferredColorScheme(.dark)
}
