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
        .fill(HomeTheme.background)
        .overlay {
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(HomeTheme.deepTurquoise, lineWidth: 2)
        }

      if isLoading {
        ProgressView()
          .tint(HomeTheme.gray60)
      } else {
        Image(AppAsset.Make.add)
          .renderingMode(.template)
          .resizable()
          .scaledToFit()
          .foregroundStyle(HomeTheme.deepTurquoise)
          .frame(width: 32, height: 32)
      }
    }
    .aspectRatio(1, contentMode: .fit)
    .frame(maxWidth: .infinity)
  }
}
