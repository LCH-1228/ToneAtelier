//
//  URLRequestBuilder.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import Foundation

struct URLRequestBuilder {
  func build<Response>(for endpoint: APIEndpoint<Response>, session: SessionSnapshot) throws -> URLRequest {
    let url = try buildURL(for: endpoint, session: session)
    try validateTokens(for: endpoint, session: session)

    var request = URLRequest(url: url)
    request.httpMethod = endpoint.method.rawValue
    request.cachePolicy = .reloadIgnoringLocalCacheData
    request.setValue(APIInfo.HeaderValue.json, forHTTPHeaderField: APIInfo.HeaderField.accept)

    applyAuthenticationHeaders(to: &request, endpoint: endpoint, session: session)

    for (header, value) in endpoint.headers {
      request.setValue(value, forHTTPHeaderField: header)
    }

    applyBody(to: &request, body: endpoint.body)
    return request
  }

  private func buildURL<Response>(
    for endpoint: APIEndpoint<Response>,
    session: SessionSnapshot
  ) throws -> URL {
    guard var components = URLComponents(
      url: session.configuration.baseURL,
      resolvingAgainstBaseURL: false
    ) else {
      throw APIError.invalidBaseURL(session.configuration.baseURL.absoluteString)
    }

    let basePath = components.percentEncodedPath == "/" ? "" : components.percentEncodedPath
    let normalizedBasePath = basePath.hasSuffix("/") ? String(basePath.dropLast()) : basePath
    let normalizedEndpointPath = endpoint.path.hasPrefix("/") ? endpoint.path : "/\(endpoint.path)"
    components.percentEncodedPath = normalizedBasePath + normalizedEndpointPath
    components.queryItems = endpoint.queryItems.isEmpty ? nil : endpoint.queryItems

    guard let url = components.url else {
      throw APIError.invalidURL(endpoint.path)
    }
    return url
  }

  private func validateTokens<Response>(
    for endpoint: APIEndpoint<Response>,
    session: SessionSnapshot
  ) throws {
    if endpoint.requiresAccessToken, session.accessToken.trimmed.isEmpty {
      throw APIError.missingAccessToken
    }
    if endpoint.requiresRefreshToken, session.refreshToken.trimmed.isEmpty {
      throw APIError.missingRefreshToken
    }
  }

  private func applyAuthenticationHeaders<Response>(
    to request: inout URLRequest,
    endpoint: APIEndpoint<Response>,
    session: SessionSnapshot
  ) {
    if !session.configuration.seSACKey.trimmed.isEmpty {
      request.setValue(session.configuration.seSACKey.trimmed, forHTTPHeaderField: APIInfo.HeaderField.seSACKey)
    }
    if endpoint.requiresAccessToken {
      request.setValue(session.accessToken.trimmed, forHTTPHeaderField: APIInfo.HeaderField.authorization)
    }
    if endpoint.requiresRefreshToken {
      request.setValue(session.refreshToken.trimmed, forHTTPHeaderField: APIInfo.HeaderField.refreshToken)
    }
  }

  private func applyBody(to request: inout URLRequest, body: HTTPBody) {
    switch body {
    case .none:
      break
    case let .json(data):
      request.httpBody = data
      request.setValue(APIInfo.HeaderValue.json, forHTTPHeaderField: APIInfo.HeaderField.contentType)
    case let .multipart(formData):
      let payload = MultipartFormDataBuilder().build(formData)
      request.httpBody = payload.data
      request.setValue(payload.contentType, forHTTPHeaderField: APIInfo.HeaderField.contentType)
    }
  }
}

private struct MultipartPayload {
  let data: Data
  let contentType: String
}

private struct MultipartFormDataBuilder {
  func build(_ formData: MultipartFormData) -> MultipartPayload {
    let boundary = "Boundary-\(UUID().uuidString)"
    var data = Data()

    for part in formData.parts {
      switch part {
      case let .text(name, value):
        data.append(Data("--\(boundary)\r\n".utf8))
        data.append(Data("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".utf8))
        data.append(Data("\(value)\r\n".utf8))
      case let .file(file):
        data.append(Data("--\(boundary)\r\n".utf8))
        let asciiSafe = makeASCIISafeFilename(file.fileName)
        let disposition = "Content-Disposition: form-data; name=\"\(file.fieldName)\"; filename=\"\(asciiSafe)\"\r\n"
        data.append(Data(disposition.utf8))
        data.append(Data("Content-Type: \(file.mimeType)\r\n\r\n".utf8))
        data.append(file.data)
        data.append(Data("\r\n".utf8))
      }
    }

    data.append(Data("--\(boundary)--\r\n".utf8))

    return MultipartPayload(
      data: data,
      contentType: "multipart/form-data; boundary=\(boundary)"
    )
  }
}

/// 비ASCII / multipart-unsafe 문자를 underscore로 치환. 빈 결과는 "attachment"로 대체.
private func makeASCIISafeFilename(_ original: String) -> String {
  let unsafeCharacters: Set<Character> = ["\"", "\\", "\r", "\n"]
  var result = ""
  for scalar in original.unicodeScalars {
    let char = Character(scalar)
    if scalar.isASCII && !unsafeCharacters.contains(char) {
      result.append(char)
    } else {
      result.append("_")
    }
  }
  let trimmed = result.trimmingCharacters(in: .whitespaces)
  if trimmed.isEmpty || trimmed == "_" {
    if let dotIndex = original.lastIndex(of: "."),
       case let ext = original[original.index(after: dotIndex)...],
       ext.allSatisfy({ $0.isASCII }),
       !ext.isEmpty {
      return "attachment.\(ext)"
    }
    return "attachment"
  }
  return trimmed
}
