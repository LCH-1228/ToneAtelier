//
//  LiveImageDiskStore.swift
//  ToneAtelier
//
//  Created by LCH on 4/29/26.
//

import CryptoKit
import Foundation

/// 채팅 사진을 비롯한 모든 인증 이미지의 영구 디스크 저장소.
///
/// `Library/Application Support/ChatImages/` 디렉토리에 `SHA256(path).{ext}` 파일명으로 저장한다.
/// `Library/Caches`가 아닌 `Application Support`에 두는 이유:
/// - `Caches`는 OS가 디스크 압박 상황에서 임의로 삭제할 수 있다.
/// - 채팅 사진은 사용자 명시 정책상 만료 없이 영구 보관해야 하므로, OS 자동 삭제 대상에서 제외해야 한다.
/// - 사용자 로그아웃 같은 명시적 시점에서만 삭제(`clearAll`)된다.
///
/// 모든 입출력은 `actor` 격리 안에서 수행되어 동시성 충돌이 없고, 호출 측 메인 스레드를 차단하지 않는다.
actor LiveImageDiskStore {
  static let shared = LiveImageDiskStore()

  private let directoryURL: URL
  private let fileManager: FileManager

  init(
    directoryURL: URL? = nil,
    fileManager: FileManager = .default
  ) {
    self.fileManager = fileManager
    if let directoryURL {
      self.directoryURL = directoryURL
    } else {
      let baseURL = fileManager.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
      ).first!
      self.directoryURL = baseURL.appendingPathComponent("ChatImages", isDirectory: true)
    }
    try? fileManager.createDirectory(
      at: self.directoryURL,
      withIntermediateDirectories: true
    )
  }

  func read(path: String) -> Data? {
    let url = fileURL(for: path)
    return try? Data(contentsOf: url)
  }

  func write(_ data: Data, path: String) {
    let url = fileURL(for: path)
    try? data.write(to: url, options: .atomic)
  }

  func delete(path: String) {
    let url = fileURL(for: path)
    try? fileManager.removeItem(at: url)
  }

  func clearAll() {
    try? fileManager.removeItem(at: directoryURL)
    try? fileManager.createDirectory(
      at: directoryURL,
      withIntermediateDirectories: true
    )
  }

  // MARK: - Internal

  /// 파일 존재 여부와 무관하게 path → 디스크 파일 URL을 결정한다.
  /// 외부에서 미리보기/공유 등 raw URL이 필요할 때 사용한다(actor 격리이므로 호출 시 `await` 필요).
  func fileURL(for path: String) -> URL {
    let key = sha256Hex(path)
    let ext = inferExtension(from: path)
    return directoryURL.appendingPathComponent("\(key).\(ext)")
  }

  // MARK: - Private

  private func sha256Hex(_ string: String) -> String {
    let digest = SHA256.hash(data: Data(string.utf8))
    return digest.map { String(format: "%02x", $0) }.joined()
  }

  private func inferExtension(from path: String) -> String {
    if let ext = path.split(separator: ".").last,
       !ext.isEmpty,
       ext.count <= 5 {
      return String(ext).lowercased()
    }
    return "bin"
  }
}
