//
//  HTTPTypes.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import Foundation

enum HTTPMethod: String, Sendable {
  case get = "GET"
  case post = "POST"
  case put = "PUT"
  case delete = "DELETE"
}

struct UploadFile: Equatable, Sendable {
  let fieldName: String
  let fileName: String
  let mimeType: String
  let data: Data

  init(fieldName: String, fileName: String, mimeType: String, data: Data) {
    self.fieldName = fieldName
    self.fileName = fileName
    self.mimeType = mimeType
    self.data = data
  }
}

struct MultipartFormData: Equatable, Sendable {
  enum Part: Equatable, Sendable {
    case text(name: String, value: String)
    case file(UploadFile)
  }

  let parts: [Part]
}

enum HTTPBody: Equatable, Sendable {
  case none
  case json(Data)
  case multipart(MultipartFormData)

  static func jsonBody<T: Encodable>(_ value: T, encoder: JSONEncoder = .api) throws -> HTTPBody {
    .json(try encoder.encode(value))
  }
}

struct APIEndpoint<Response>: Sendable {
  let method: HTTPMethod
  let path: String
  let queryItems: [URLQueryItem]
  let headers: [String: String]
  let body: HTTPBody
  let requiresAccessToken: Bool
  let requiresRefreshToken: Bool
  let parse: @Sendable (_ data: Data, _ response: HTTPURLResponse, _ decoder: JSONDecoder) throws -> Response

  init(
    method: HTTPMethod,
    path: String,
    queryItems: [URLQueryItem] = [],
    headers: [String: String] = [:],
    body: HTTPBody = .none,
    requiresAccessToken: Bool = false,
    requiresRefreshToken: Bool = false,
    parse: @escaping @Sendable (_ data: Data, _ response: HTTPURLResponse, _ decoder: JSONDecoder) throws -> Response
  ) {
    self.method = method
    self.path = path
    self.queryItems = queryItems
    self.headers = headers
    self.body = body
    self.requiresAccessToken = requiresAccessToken
    self.requiresRefreshToken = requiresRefreshToken
    self.parse = parse
  }
}

extension APIEndpoint where Response: Decodable {
  init(
    method: HTTPMethod,
    path: String,
    queryItems: [URLQueryItem] = [],
    headers: [String: String] = [:],
    body: HTTPBody = .none,
    requiresAccessToken: Bool = false,
    requiresRefreshToken: Bool = false
  ) {
    self.init(
      method: method,
      path: path,
      queryItems: queryItems,
      headers: headers,
      body: body,
      requiresAccessToken: requiresAccessToken,
      requiresRefreshToken: requiresRefreshToken
    ) { data, _, decoder in
      if Response.self == EmptyResponse.self {
        return EmptyResponse() as! Response
      }

      guard !data.isEmpty else {
        throw APIError.decoding("비어 있는 응답입니다.")
      }
      
      do {
        return try decoder.decode(Response.self, from: data)
      } catch {
        throw APIError.decoding(error.localizedDescription)
      }
    }
  }
}

extension JSONEncoder {
  static var api: JSONEncoder {
    JSONEncoder()
  }
}

extension JSONDecoder {
  static var api: JSONDecoder {
    JSONDecoder()
  }
}
