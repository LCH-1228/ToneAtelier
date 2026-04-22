//
//  URLQueryItem+Helpers.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import Foundation

extension URLQueryItem {
  static func optional(name: String, value: String?) -> URLQueryItem? {
    guard let value = value?.trimmed, !value.isEmpty else { return nil }
    return URLQueryItem(name: name, value: value)
  }

  static func optional<T: CustomStringConvertible>(name: String, value: T?) -> URLQueryItem? {
    guard let value else { return nil }
    return URLQueryItem(name: name, value: value.description)
  }
}
