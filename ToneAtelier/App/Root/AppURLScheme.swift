//
//  AppURLScheme.swift
//  ToneAtelier
//
//  Created by Claude on 4/29/26.
//

import Foundation

/// 앱이 처리하는 커스텀 URL Scheme 상수 모음.
///
/// - 외부 SDK(아임포트 등)와 OS 간의 복귀 경로 식별용으로 사용한다.
/// - 새 값을 추가할 때는 반드시 `Info.plist`의 `CFBundleURLSchemes`와 일치시킨다.
enum AppURLScheme {
  /// 아임포트 결제 후 외부 카드앱(ISP 등)에서 앱으로 복귀할 때 사용하는 스킴.
  ///
  /// `Info.plist`의 `CFBundleURLSchemes` 항목과 동일해야 한다.
  static let payment = "mitti-toneatelier"
}
