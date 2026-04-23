//
//  URLRequestBuilder.swift
//  ToneAtelier
//
//  Created by LCH on 4/22/26.
//

import Foundation

struct URLRequestBuilder {
  func build<Response>(for endpoint: APIEndpoint<Response>, session: SessionSnapshot) throws -> URLRequest {
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

    if endpoint.requiresAccessToken, session.accessToken.trimmed.isEmpty {
      throw APIError.missingAccessToken
    }

    if endpoint.requiresRefreshToken, session.refreshToken.trimmed.isEmpty {
      throw APIError.missingRefreshToken
    }

    var request = URLRequest(url: url)
    request.httpMethod = endpoint.method.rawValue
    request.setValue(APIInfo.HeaderValue.json, forHTTPHeaderField: APIInfo.HeaderField.accept)

    if !session.configuration.seSACKey.trimmed.isEmpty {
      request.setValue(session.configuration.seSACKey.trimmed, forHTTPHeaderField: APIInfo.HeaderField.seSACKey)
    }

    if endpoint.requiresAccessToken {
      request.setValue(
        "\(session.accessToken.trimmed)",
        forHTTPHeaderField: APIInfo.HeaderField.authorization
      )
    }

    if endpoint.requiresRefreshToken {
      request.setValue(session.refreshToken.trimmed, forHTTPHeaderField: APIInfo.HeaderField.refreshToken)
    }

    for (header, value) in endpoint.headers {
      request.setValue(value, forHTTPHeaderField: header)
    }

    switch endpoint.body {
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

    return request
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
        data.append(Data("Content-Disposition: form-data; name=\"\(file.fieldName)\"; filename=\"\(file.fileName)\"\r\n".utf8))
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
