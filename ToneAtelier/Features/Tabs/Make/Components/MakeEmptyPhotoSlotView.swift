//
//  MakeEmptyPhotoSlotView.swift
//  ToneAtelier
//
//  Created by Codex on 4/28/26.
//

import SwiftUI

struct MakeEmptyPhotoSlotView: View {
  let isLoading: Bool

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(HomeTheme.blackTurquoise)

      if isLoading {
        ProgressView()
          .tint(HomeTheme.gray60)
      } else {
        Image(AppAsset.Make.add)
          .renderingMode(.template)
          .resizable()
          .scaledToFit()
          .foregroundStyle(HomeTheme.gray75)
          .frame(width: 32, height: 32)
      }
    }
    .frame(maxWidth: .infinity, minHeight: 100, maxHeight: 100)
  }
}

#Preview {
  MakeEmptyPhotoSlotView(isLoading: false)
}
