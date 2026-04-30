//
//  ChatImageDecodedCache.swift
//  ToneAtelier
//
//  Created by LCH on 4/29/26.
//

import UIKit

/// 디코딩된 `UIImage`만 보관하는 메모리 캐시.
///
/// 데이터 단계 캐시(`LiveImageStore` actor)는 raw `Data`만 가지고 있어 화면이 바뀔 때마다
/// `UIImage(data:)` 디코딩이 반복된다. 그 비용을 줄이기 위해 본 캐시는 디코딩된 인스턴스를
/// 보관하고, 시스템 메모리 압박 시 `NSCache`가 자동으로 비운다.
///
/// `actor`로 격리해 동시 접근을 직렬화한다. `NSCache` 자체는 thread-safe지만,
/// `@unchecked Sendable` 우회 대신 actor 경계로 안전성을 명시화한다.
actor ChatImageDecodedCache {
  static let shared = ChatImageDecodedCache()

  private let cache = NSCache<NSString, UIImage>()

  private init() {
    // 메모리 압박 시 시스템이 자동 비움. 명시적 totalCostLimit은 두지 않는다.
    cache.countLimit = 200
  }

  func image(for key: String) -> UIImage? {
    cache.object(forKey: key as NSString)
  }

  func set(_ image: UIImage, for key: String) {
    cache.setObject(image, forKey: key as NSString)
  }
}
