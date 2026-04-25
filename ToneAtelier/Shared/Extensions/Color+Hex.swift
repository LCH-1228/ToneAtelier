//
//  Color+Hex.swift
//  ToneAtelier
//
//  Created by Codex on 4/24/26.
//

import SwiftUI

extension Color {
  init(hex: UInt32, opacity: Double = 1) {
    self.init(
      .sRGB,
      red: Double((hex & 0xFF0000) >> 16) / 255,
      green: Double((hex & 0x00FF00) >> 8) / 255,
      blue: Double(hex & 0x0000FF) / 255,
      opacity: opacity
    )
  }
}
