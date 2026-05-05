//
//  VideoOfficialAvatar.swift
//  ToneAtelier
//
//  Created by Codex on 5/5/26.
//

import SwiftUI

struct VideoOfficialAvatar: View {
  let size: CGFloat

  var body: some View {
    ZStack {
      Circle()
        .fill(AppTheme.brightTurquoise)
      Circle()
        .strokeBorder(Color(hex: 0x4F8190), lineWidth: 1)
      Text("T")
        .font(.custom("OTHakgyoansimMulgyeolR", size: size * 0.55))
        .foregroundStyle(.white)
    }
    .frame(width: size, height: size)
  }
}
