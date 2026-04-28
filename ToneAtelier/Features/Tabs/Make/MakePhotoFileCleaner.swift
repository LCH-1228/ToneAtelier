//
//  MakePhotoFileCleaner.swift
//  ToneAtelier
//
//  Created by Codex on 4/29/26.
//

import Foundation

enum MakePhotoFileCleaner {
  nonisolated static func removeFileIfNeeded(at fileURL: URL?) {
    guard let fileURL else { return }
    try? FileManager.default.removeItem(at: fileURL)
  }
}
