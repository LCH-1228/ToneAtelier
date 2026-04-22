//
//  JSONValue.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import Foundation

enum JSONValue: Equatable, Sendable, Codable {
  case string(String)
  case number(Double)
  case boolean(Bool)
  case object([String: JSONValue])
  case array([JSONValue])
  case null

  init(from decoder: Decoder) throws {
    if let container = try? decoder.singleValueContainer() {
      if container.decodeNil() {
        self = .null
      } else if let value = try? container.decode(Bool.self) {
        self = .boolean(value)
      } else if let value = try? container.decode(Double.self) {
        self = .number(value)
      } else if let value = try? container.decode(String.self) {
        self = .string(value)
      } else if let value = try? container.decode([String: JSONValue].self) {
        self = .object(value)
      } else if let value = try? container.decode([JSONValue].self) {
        self = .array(value)
      } else {
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value.")
      }
    } else {
      throw DecodingError.dataCorrupted(
        .init(codingPath: decoder.codingPath, debugDescription: "Unsupported decoder container.")
      )
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()

    switch self {
    case let .string(value):
      try container.encode(value)
    case let .number(value):
      try container.encode(value)
    case let .boolean(value):
      try container.encode(value)
    case let .object(value):
      try container.encode(value)
    case let .array(value):
      try container.encode(value)
    case .null:
      try container.encodeNil()
    }
  }
}
