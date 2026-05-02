//
//  KeychainPushTokenStore.swift
//  ToneAtelier
//
//  Created by Codex on 5/2/26.
//

import Foundation
import OSLog
import Security

actor KeychainPushTokenStore {
  private enum TokenKey: String, CaseIterable {
    case fcmToken
  }

  private let service: String

  // 세션 토큰 저장소(`ToneAtelier.session`)와 분리해 키 충돌과 일괄 삭제 영향을 차단한다.
  init(service: String = "ToneAtelier.push") {
    self.service = service
  }

  func read() -> String? {
    readToken(for: .fcmToken)
  }

  func update(_ token: String?) {
    guard let token else {
      deleteToken(for: .fcmToken)
      return
    }

    let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      deleteToken(for: .fcmToken)
      return
    }

    do {
      try upsertToken(trimmed, for: .fcmToken)
    } catch {
      report(error)
    }
  }

  func clear() {
    TokenKey.allCases.forEach(deleteToken)
  }

  private func readToken(for key: TokenKey) -> String? {
    do {
      return try loadToken(for: key)
    } catch {
      report(error)
      return nil
    }
  }

  private func deleteToken(for key: TokenKey) {
    do {
      try deleteValue(for: key)
    } catch {
      report(error)
    }
  }

  private func query(for key: TokenKey) -> [CFString: Any] {
    [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: key.rawValue
    ]
  }

  private func loadToken(for key: TokenKey) throws -> String? {
    var query = query(for: key)
    query[kSecMatchLimit] = kSecMatchLimitOne
    query[kSecReturnData] = true

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)

    switch status {
    case errSecSuccess:
      guard
        let data = item as? Data,
        let token = String(data: data, encoding: .utf8)
      else {
        throw KeychainPushTokenStoreError.invalidTokenData
      }

      return token

    case errSecItemNotFound:
      return nil

    default:
      throw KeychainPushTokenStoreError.unexpectedStatus(status, operation: "load")
    }
  }

  private func upsertToken(_ value: String, for key: TokenKey) throws {
    let data = Data(value.utf8)
    let status = SecItemUpdate(
      query(for: key) as CFDictionary,
      [kSecValueData: data] as CFDictionary
    )

    switch status {
    case errSecSuccess:
      return

    case errSecItemNotFound:
      var newItem = query(for: key)
      newItem[kSecValueData] = data
      // 백그라운드 푸시 등록 시점에도 접근 가능해야 하며, 기기 백업으로 새어나가지 않도록 한다.
      newItem[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

      let addStatus = SecItemAdd(newItem as CFDictionary, nil)
      guard addStatus == errSecSuccess else {
        throw KeychainPushTokenStoreError.unexpectedStatus(addStatus, operation: "add")
      }

    default:
      throw KeychainPushTokenStoreError.unexpectedStatus(status, operation: "update")
    }
  }

  private func deleteValue(for key: TokenKey) throws {
    let status = SecItemDelete(query(for: key) as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw KeychainPushTokenStoreError.unexpectedStatus(status, operation: "delete")
    }
  }

  private func report(_ error: Error) {
    Logger.push.error("Keychain push token error: \(error.localizedDescription, privacy: .private)")
#if DEBUG
    assertionFailure("KeychainPushTokenStore error: \(error.localizedDescription)")
#endif
  }
}

private enum KeychainPushTokenStoreError: LocalizedError {
  case invalidTokenData
  case unexpectedStatus(OSStatus, operation: String)

  var errorDescription: String? {
    switch self {
    case .invalidTokenData:
      return "Keychain 푸시 토큰 데이터를 문자열로 변환하지 못했습니다."

    case let .unexpectedStatus(status, operation):
      let message = SecCopyErrorMessageString(status, nil) as String? ?? "알 수 없는 Keychain 오류"
      return "Keychain \(operation) 실패: \(message) (\(status))"
    }
  }
}
