//
//  AuthResponseDTO.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import Foundation

/// spec LoginDTO. 기존 AuthenticatedUserResponse와 동일 스키마이므로 alias로 노출.
typealias LoginDTO = AuthenticatedUserResponse

/// spec JoinResponseDTO. 동일 스키마이므로 alias로 노출(profileImage가 spec상 미포함이지만 응답 호환을 위해 동일 타입 사용).
typealias JoinResponseDTO = AuthenticatedUserResponse

/// spec RefreshTokenResponseDTO. 기존 TokenRefreshResponse와 동일 스키마이므로 alias로 노출.
typealias RefreshTokenResponseDTO = TokenRefreshResponse
