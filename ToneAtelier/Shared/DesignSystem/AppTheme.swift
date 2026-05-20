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

  @available(*, deprecated, message: "Use AppTheme.Pretendard token via .pretendard(_:) view modifier")
  static func pretendard(size: CGFloat, weight: Font.Weight) -> Font {
    switch weight {
    case .bold, .semibold:
      return .custom("Pretendard-Bold", size: size)
    case .medium:
      return .custom("Pretendard-Medium", size: size)
    default:
      return .custom("Pretendard-Regular", size: size)
    }
  }

  @available(*, deprecated, message: "Use AppTheme.Mulgyeol token via .mulgyeol(_:) view modifier")
  static func mulgyeol(size: CGFloat, weight: Font.Weight = .regular) -> Font {
    switch weight {
    case .bold, .semibold:
      return .custom("OTHakgyoansimMulgyeolB", size: size)
    default:
      return .custom("OTHakgyoansimMulgyeolR", size: size)
    }
  }

  static func symbol(size: CGFloat, weight: Font.Weight = .regular) -> Font {
    .system(size: size, weight: weight)
  }
}

// MARK: - Typography Tokens

extension AppTheme {
  enum Pretendard {
    case title1
    case body1
    case body2
    case body3
    case body3Bold
    case caption1
    case captionBold
    case captionParagraph
    case captionMeta
    case caption2
    case caption2Bold
    case caption3

    var size: CGFloat {
      switch self {
      case .title1: return 20
      case .body1: return 16
      case .body2: return 14
      case .body3, .body3Bold: return 13
      case .caption1, .captionBold, .captionParagraph: return 12
      case .captionMeta: return 11
      case .caption2, .caption2Bold: return 10
      case .caption3: return 8
      }
    }

    var weight: Font.Weight {
      switch self {
      case .title1, .body3Bold, .captionBold, .captionMeta, .caption2Bold:
        return .bold
      case .body1, .body2, .body3:
        return .medium
      case .caption1, .captionParagraph, .caption2, .caption3:
        return .regular
      }
    }

    var tracking: CGFloat {
      switch self {
      case .title1, .body3, .body3Bold, .caption1, .captionBold, .captionParagraph:
        return -1
      case .body1: return -0.5
      case .body2: return -0.14
      case .captionMeta, .caption2, .caption2Bold: return -0.1
      case .caption3: return -0.08
      }
    }

    var lineHeightMultiplier: CGFloat {
      switch self {
      case .title1, .body2, .body3, .body3Bold:
        return 1.45
      case .body1: return 1.6
      case .caption1, .captionBold, .captionMeta, .caption2, .caption2Bold, .caption3:
        return 1.3
      case .captionParagraph: return 1.7
      }
    }

    var fontName: String {
      switch weight {
      case .bold: return "Pretendard-Bold"
      case .medium: return "Pretendard-Medium"
      default: return "Pretendard-Regular"
      }
    }

    var font: Font {
      .custom(fontName, size: size)
    }

    var lineSpacing: CGFloat {
      (lineHeightMultiplier - 1) * size
    }
  }

  enum Mulgyeol {
    case title1
    case display
    case pageTitle
    case body1
    case bodyNormal
    case smallTitle
    case caption1

    var size: CGFloat {
      switch self {
      case .title1, .display: return 32
      case .pageTitle: return 21
      case .body1, .bodyNormal: return 20
      case .smallTitle: return 18
      case .caption1: return 14
      }
    }

    var weight: Font.Weight {
      switch self {
      case .title1, .body1: return .bold
      case .display, .pageTitle, .bodyNormal, .smallTitle, .caption1:
        return .regular
      }
    }

    var lineHeightMultiplier: CGFloat? {
      switch self {
      case .pageTitle, .smallTitle: return 1
      default: return nil
      }
    }

    var fontName: String {
      switch weight {
      case .bold: return "OTHakgyoansimMulgyeolB"
      default: return "OTHakgyoansimMulgyeolR"
      }
    }

    var font: Font {
      .custom(fontName, size: size)
    }

    var lineSpacing: CGFloat {
      guard let multiplier = lineHeightMultiplier else { return 0 }
      return (multiplier - 1) * size
    }
  }
}

// MARK: - Typography View Modifiers

extension View {
  func pretendard(_ token: AppTheme.Pretendard) -> some View {
    self
      .font(token.font)
      .tracking(token.tracking)
      .lineSpacing(token.lineSpacing)
  }

  func mulgyeol(_ token: AppTheme.Mulgyeol) -> some View {
    self
      .font(token.font)
      .lineSpacing(token.lineSpacing)
  }
}
