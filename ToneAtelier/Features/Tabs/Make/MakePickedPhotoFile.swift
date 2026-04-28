//
//  MakePickedPhotoFile.swift
//  ToneAtelier
//
//  Created by Codex on 4/28/26.
//

import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct MakePickedPhotoFile: Equatable, Sendable, Transferable {
  let url: URL

  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(importedContentType: .image) { receivedFile in
      let fileExtension = receivedFile.file.pathExtension.isEmpty
        ? "jpg"
        : receivedFile.file.pathExtension
      let destinationURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("toneatelier-photo-\(UUID().uuidString)")
        .appendingPathExtension(fileExtension)

      try FileManager.default.copyItem(at: receivedFile.file, to: destinationURL)
      return MakePickedPhotoFile(url: destinationURL)
    }
  }
}
