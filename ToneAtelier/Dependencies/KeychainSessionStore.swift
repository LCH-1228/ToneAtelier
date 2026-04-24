//
//  KeychainSessionStore.swift
//  ToneAtelier
//
//  Created by Codex on 4/24/26.
//

import Foundation
import Security

actor KeychainSessionStore {
  private enum TokenKey: String, CaseIterable {
    case accessToken
    case refreshToken
  }

  private let service: String

  init(service: String = "ToneAtelier.session") {
    self.service = service
  }

  func snapshot() async -> SessionSnapshot {
    let configuration = await MainActor.run { APIConfiguration.default }

    return SessionSnapshot(
      configuration: configuration,
      accessToken: readToken(for: .accessToken) ?? "",
      refreshToken: readToken(for: .refreshToken) ?? ""
    )
  }

  func updateTokens(accessToken: String?, refreshToken: String?) {
    updateToken(accessToken, for: .accessToken)
    updateToken(refreshToken, for: .refreshToken)
  }

  func clearTokens() {
    TokenKey.allCases.forEach(deleteToken)
  }

  private func updateToken(_ value: String?, for key: TokenKey) {
    guard let value else { return }

    let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedValue.isEmpty else { return }

    do {
      try upsertToken(trimmedValue, for: key)
    } catch {
      report(error)
    }
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
        throw KeychainSessionStoreError.invalidTokenData
      }

      return token

    case errSecItemNotFound:
      return nil

    default:
      throw KeychainSessionStoreError.unexpectedStatus(status, operation: "load")
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
      newItem[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

      let addStatus = SecItemAdd(newItem as CFDictionary, nil)
      guard addStatus == errSecSuccess else {
        throw KeychainSessionStoreError.unexpectedStatus(addStatus, operation: "add")
      }

    default:
      throw KeychainSessionStoreError.unexpectedStatus(status, operation: "update")
    }
  }

  private func deleteValue(for key: TokenKey) throws {
    let status = SecItemDelete(query(for: key) as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw KeychainSessionStoreError.unexpectedStatus(status, operation: "delete")
    }
  }

  private func report(_ error: Error) {
#if DEBUG
    assertionFailure("KeychainSessionStore error: \(error.localizedDescription)")
#endif
  }
}

enum LiveSessionStore {
  static let shared = KeychainSessionStore()
}

private enum KeychainSessionStoreError: LocalizedError {
  case invalidTokenData
  case unexpectedStatus(OSStatus, operation: String)

  var errorDescription: String? {
    switch self {
    case .invalidTokenData:
      return "Keychain 토큰 데이터를 문자열로 변환하지 못했습니다."

    case let .unexpectedStatus(status, operation):
      let message = SecCopyErrorMessageString(status, nil) as String? ?? "알 수 없는 Keychain 오류"
      return "Keychain \(operation) 실패: \(message) (\(status))"
    }
  }
}
