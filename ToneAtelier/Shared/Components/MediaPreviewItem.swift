//
//  MediaPreviewItem.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//

import Foundation

/// 풀스크린 미디어 viewer에 전달하는 단일 아이템.
///
/// `Identifiable` 채택으로 SwiftUI `fullScreenCover(item:)`에 직접 바인딩 가능.
/// path 자체가 식별자 역할 — 같은 path는 같은 viewer를 의미.
enum MediaPreviewItem: Identifiable, Equatable, Sendable {
  /// 사진 갤러리. 여러 장 paging이 가능하도록 paths + 시작 index를 함께 전달한다.
  case photo(paths: [String], initialIndex: Int)
  case video(path: String)

  var id: String {
    switch self {
    case let .photo(paths, initialIndex):
      return "photo:\(paths.joined(separator: "|")):\(initialIndex)"
    case let .video(path):
      return "video:\(path)"
    }
  }

  /// 단일 path가 필요한 호출부를 위한 helper. 영상은 그대로, 사진은 단일 path 갤러리로 변환.
  static func fromPath(_ path: String) -> MediaPreviewItem {
    MediaPathClassifier.isVideo(path)
      ? .video(path: path)
      : .photo(paths: [path], initialIndex: 0)
  }

  /// 미디어 배열에서 특정 index의 항목을 풀스크린 viewer로 펼친다.
  /// 영상이면 단일 영상 viewer, 사진이면 사진 부분만 추려 paging gallery를 만든다.
  static func from(files: [String], tappedIndex: Int) -> MediaPreviewItem? {
    guard files.indices.contains(tappedIndex) else { return nil }
    let path = files[tappedIndex]
    if MediaPathClassifier.isVideo(path) {
      return .video(path: path)
    }
    let photos = files.filter { !MediaPathClassifier.isVideo($0) }
    guard !photos.isEmpty else { return nil }
    let initial = photos.firstIndex(of: path) ?? 0
    return .photo(paths: photos, initialIndex: initial)
  }
}

/// 미디어 path의 영상 여부를 일관되게 판정한다. 카드/캐러셀/뷰어가 모두 같은 기준 사용.
enum MediaPathClassifier {
  /// 후보 영상 확장자. iOS 표준 재생 가능 포맷에 한정한다.
  /// webm 등 미지원 포맷은 사진처럼 처리되어 `ChatImageView` placeholder로 떨어진다.
  static let videoExtensions: [String] = [".mp4", ".mov", ".m4v"]

  static func isVideo(_ path: String) -> Bool {
    let lower = path.lowercased()
    return videoExtensions.contains(where: { lower.hasSuffix($0) })
  }
}
