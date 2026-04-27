//
//  MakeEditView.swift
//  ToneAtelier
//
//  Created by Codex on 4/28/26.
//

import ComposableArchitecture
import SwiftUI

struct MakeEditView: View {
  @Environment(\.dismiss) private var dismiss

  let store: StoreOf<MakeEditFeature>

  var body: some View {
    VStack(spacing: 0) {
      navigationHeader

      Text("Edit Mock")
        .font(HomeTheme.pretendard(size: 20, weight: .bold))
        .foregroundStyle(HomeTheme.gray60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(HomeTheme.background.ignoresSafeArea())
    .navigationBarBackButtonHidden(true)
    .toolbar(.hidden, for: .navigationBar)
  }

  private var navigationHeader: some View {
    HStack {
      SharedIconButton(
        accessibilityLabel: "뒤로 가기",
        action: { dismiss() }
      ) {
        Image(systemName: "chevron.left")
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(HomeTheme.gray75)
      }

      Spacer()

      Text("EDIT")
        .font(HomeTheme.mulgyeol(size: 20, weight: .bold))
        .foregroundStyle(HomeTheme.gray60)

      Spacer()

      Color.clear
        .frame(width: 48, height: 56)
    }
    .frame(height: 56)
  }
}

#Preview {
  NavigationStack {
    MakeEditView(
      store: Store(initialState: MakeEditFeature.State()) {
        MakeEditFeature()
      }
    )
  }
}
