//
//  ChatImagePlaceholder.swift
//  ToneAtelier
//
//  Created by LCH on 4/29/26.
//

import Foundation

/// `ChatImageView`가 이미지를 받기 전(또는 실패 시) 보여주는 placeholder 종류.
///
/// 실제 색상/아이콘 매핑은 `ChatImageView` 내부에서 처리하며, 이 enum은 의도만 표현한다.
enum ChatImagePlaceholder {
  /// 사진 아이콘 + blackTurquoise 배경 (첨부 이미지 셀용).
  case photo
  /// 사람 아이콘 + deepTurquoise 배경 (프로필 아바타용).
  case person
}
