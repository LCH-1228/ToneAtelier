//
//  MakePhotoCategory.swift
//  ToneAtelier
//
//  Created by Codex on 5/7/26.
//

import Foundation

enum MakePhotoCategory: String, CaseIterable, Equatable, Sendable {
  case portrait
  case landscape
  case food
  case night
  case defaultBalanced

  var localizedTitle: String {
    switch self {
    case .portrait:
      return "인물"
    case .landscape:
      return "풍경"
    case .food:
      return "음식"
    case .night:
      return "야경"
    case .defaultBalanced:
      return "기본"
    }
  }
}
