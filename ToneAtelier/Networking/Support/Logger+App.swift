//
//  Logger+App.swift
//  ToneAtelier
//
//  Created by LCH on 4/24/26.
//

import OSLog

extension Logger {
  private static let subsystem = Bundle.main.bundleIdentifier ?? "com.mitti.ToneAtelier"

  enum Category: String {
    case authSession = "AuthSession"
  }

  static func app(_ category: Category) -> Logger {
    Logger(subsystem: subsystem, category: category.rawValue)
  }

  // MARK: - Predefined

  nonisolated static let authSession = app(.authSession)
}
