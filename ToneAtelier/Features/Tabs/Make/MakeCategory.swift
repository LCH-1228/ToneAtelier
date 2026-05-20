//
//  MakeCategory.swift
//  ToneAtelier
//
//  Created by Codex on 4/28/26.
//

import Foundation

enum MakeCategory: String, CaseIterable, Identifiable, Equatable, Sendable {
  case food = "푸드"
  case people = "인물"
  case landscape = "풍경"
  case night = "야경"
  case star = "별"

  var id: String { rawValue }
}
