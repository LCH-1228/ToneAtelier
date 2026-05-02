//
//  ChatModels.swift
//  ToneAtelier
//
//  Created by LCH on 4/29/26.
//

import Foundation

/// spec UserInfoResponseDTO에 해당. 채팅 메시지 sender / 채팅방 participants에서 그대로 사용한다.
/// 신규 코드는 UserInfoResponseDTO를 직접 사용하고, 본 alias는 기존 호출부 호환을 위해 유지.
typealias ChatUserSummary = UserInfoResponseDTO

/// spec MyInfoResponseDTO에 해당. 내 프로필 응답.
typealias MyProfileResponse = MyInfoResponseDTO

/// spec UserInfoListResponseDTO에 해당.
typealias UserSearchResponse = UserInfoListResponseDTO
