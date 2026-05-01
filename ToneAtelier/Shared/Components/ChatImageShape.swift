//
//  ChatImageShape.swift
//  ToneAtelier
//
//  Created by LCH on 4/29/26.
//

import SwiftUI

/// `ChatImageView`가 외곽을 클립할 때 사용하는 도형 추상화.
///
/// `roundedRect(cornerRadius:)`는 그리드 셀처럼 직각 또는 라운드 처리가 필요한 케이스에,
/// `circle`은 프로필 아바타 같이 원형 마스크가 필요한 케이스에 사용한다.
enum ChatImageShape {
  case roundedRect(cornerRadius: CGFloat)
  case circle

  /// 호출부(`ChatImageView`)에서 `clipShape(_:)`에 그대로 전달할 수 있도록
  /// `AnyShape`로 감싼 결과를 반환한다.
  var shape: AnyShape {
    switch self {
    case let .roundedRect(cornerRadius):
      AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    case .circle:
      AnyShape(Circle())
    }
  }
}
