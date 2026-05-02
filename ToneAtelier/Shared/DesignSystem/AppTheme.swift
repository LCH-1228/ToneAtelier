//
//  AppTheme.swift
//  ToneAtelier
//
//  Created by Codex on 5/1/26.
//

import SwiftUI

enum AppTheme {
  static let background = Color(hex: 0x0B0B0B)
  static let gray15 = Color(hex: 0xF9F9F9)
  static let gray30 = Color(hex: 0xEAEAEA)
  static let gray45 = Color(hex: 0xD8D6D7)
  static let gray60 = Color(hex: 0xABABAE)
  static let gray75 = Color(hex: 0x6A6A6E)
  static let blackTurquoise = Color(hex: 0x1F2527)
  static let deepTurquoise = Color(hex: 0x293235)
  static let brightTurquoise = Color(hex: 0x315C6B)
  static let tabBarBackground = Color(hex: 0x6A6A6E, opacity: 0.5)

  static func pretendard(size: CGFloat, weight: Font.Weight) -> Font {
    switch weight {
    case .bold:
      return .custom("Pretendard-Bold", size: size)
    case .semibold:
      return .custom("Pretendard-SemiBold", size: size)
    case .medium:
      return .custom("Pretendard-Medium", size: size)
    default:
      return .custom("Pretendard-Regular", size: size)
    }
  }

  static func mulgyeol(size: CGFloat, weight: Font.Weight = .regular) -> Font {
    switch weight {
    case .bold, .semibold:
      return .custom("HakgyoansimMulgyeolOTFB", size: size)
    default:
      return .custom("HakgyoansimMulgyeolOTFR", size: size)
    }
  }

  static func symbol(size: CGFloat, weight: Font.Weight = .regular) -> Font {
    .system(size: size, weight: weight)
  }
}
