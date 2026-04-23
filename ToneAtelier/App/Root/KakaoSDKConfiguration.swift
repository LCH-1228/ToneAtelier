//
//  KakaoSDKConfiguration.swift
//  ToneAtelier
//
//  Created by Codex on 4/23/26.
//

import Foundation

enum KakaoSDKConfiguration {
  static var nativeAppKey: String? {
    guard let value = Bundle.main.object(forInfoDictionaryKey: "KakaoNativeAppKey") as? String else {
      return nil
    }

    let appKey = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !appKey.isEmpty, !appKey.hasPrefix("$(") else { return nil }
    return appKey
  }

  static var isConfigured: Bool {
    nativeAppKey != nil
  }
}
