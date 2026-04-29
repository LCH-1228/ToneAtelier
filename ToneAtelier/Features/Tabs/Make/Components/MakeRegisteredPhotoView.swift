//
//  MakeRegisteredPhotoView.swift
//  ToneAtelier
//
//  Created by Codex on 4/28/26.
//

import SwiftUI
import UIKit

struct MakeRegisteredPhotoView: View {
  let image: UIImage

  var body: some View {
    Image(uiImage: image)
      .resizable()
      .scaledToFit()
      .frame(maxWidth: .infinity)
      .frame(maxHeight: 350)
      .background(HomeTheme.blackTurquoise)
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .stroke(HomeTheme.deepTurquoise, lineWidth: 2)
      }
  }
}
