//
//  HomeAttendanceWebView.swift
//  ToneAtelier
//
//  Created by Codex on 4/25/26.
//

import SwiftUI
import WebKit

struct HomeAttendanceWebView: UIViewRepresentable {

  let webViewRequest: WebViewRequest
  let accessToken: String
  let onAttendanceCompleted: (Int?) -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(
      accessToken: accessToken,
      onAttendanceCompleted: onAttendanceCompleted
    )
  }

  func makeUIView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    let controller = configuration.userContentController

    controller.add(context.coordinator, name: Coordinator.ScriptMessage.clickAttendanceButton)
    controller.add(context.coordinator, name: Coordinator.ScriptMessage.completeAttendance)

    let webView = WKWebView(frame: .zero, configuration: configuration)
    context.coordinator.webView = webView
    webView.load(webViewRequest.urlRequest)
    return webView
  }

  func updateUIView(_ webView: WKWebView, context: Context) {
    context.coordinator.accessToken = accessToken
  }

  static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
    webView.configuration.userContentController.removeScriptMessageHandler(
      forName: Coordinator.ScriptMessage.clickAttendanceButton
    )
    webView.configuration.userContentController.removeScriptMessageHandler(
      forName: Coordinator.ScriptMessage.completeAttendance
    )
    coordinator.webView = nil
  }
}

extension HomeAttendanceWebView {
  final class Coordinator: NSObject, WKScriptMessageHandler {
    enum ScriptMessage {
      static let clickAttendanceButton = "click_attendance_button"
      static let completeAttendance = "complete_attendance"
    }

    var accessToken: String
    let onAttendanceCompleted: (Int?) -> Void
    weak var webView: WKWebView?

    init(
      accessToken: String,
      onAttendanceCompleted: @escaping (Int?) -> Void
    ) {
      self.accessToken = accessToken
      self.onAttendanceCompleted = onAttendanceCompleted
    }

    func userContentController(
      _ userContentController: WKUserContentController,
      didReceive message: WKScriptMessage
    ) {
      switch message.name {
      case ScriptMessage.clickAttendanceButton:
        guard !accessToken.trimmed.isEmpty else { return }
        webView?.evaluateJavaScript(attendanceRequestJavaScript(with: accessToken))

      case ScriptMessage.completeAttendance:
        onAttendanceCompleted(attendanceCount(from: message.body))

      default:
        break
      }
    }

    private func attendanceCount(from body: Any) -> Int? {
      if let count = body as? Int {
        return count
      }

      if let countString = body as? String {
        return Int(countString)
      }

      return nil
    }

    private func attendanceRequestJavaScript(with accessToken: String) -> String {
      "requestAttendance('\(accessToken.javaScriptSingleQuotedEscaped)')"
    }
  }
}

private extension String {
  var javaScriptSingleQuotedEscaped: String {
    replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "'", with: "\\'")
      .replacingOccurrences(of: "\n", with: "\\n")
      .replacingOccurrences(of: "\r", with: "\\r")
  }
}

private extension WebViewRequest {
  var urlRequest: URLRequest {
    var request = URLRequest(
      url: url,
      cachePolicy: .reloadIgnoringLocalCacheData
    )
    for (header, value) in headers {
      request.setValue(value, forHTTPHeaderField: header)
    }
    return request
  }
}
