//
//  UserRequestDTO.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import Foundation

struct EmailValidationRequestDTO: Encodable, Equatable, Sendable {
  let email: String
}

struct JoinRequestDTO: Encodable, Equatable, Sendable {
  let email: String
  let password: String
  let nick: String
  let name: String
  let introduction: String?
  let phoneNum: String?
  let hashTags: [String]?
  let deviceToken: String?
}

struct EmailLoginRequestDTO: Encodable, Equatable, Sendable {
  let email: String
  let password: String
  let deviceToken: String?
}

struct KakaoLoginRequestDTO: Encodable, Equatable, Sendable {
  let oauthToken: String
  let deviceToken: String?
}

struct AppleLoginRequestDTO: Encodable, Equatable, Sendable {
  let idToken: String
  let deviceToken: String?
}

struct DeviceTokenRequestDTO: Encodable, Equatable, Sendable {
  let deviceToken: String
}

struct ProfileRequestDTO: Encodable, Equatable, Sendable {
  let nick: String?
  let name: String?
  let introduction: String?
  let phoneNum: String?
  let profileImage: String?
  let hashTags: [String]?
}
