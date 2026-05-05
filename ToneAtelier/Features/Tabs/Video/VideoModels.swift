//
//  VideoModels.swift
//  ToneAtelier
//
//  Created by Codex on 5/5/26.
//

import Foundation

enum VideoMetaFormatter {
  static func formatDuration(_ seconds: Double) -> String {
    let total = max(0, Int(seconds.rounded()))
    let h = total / 3600
    let m = (total % 3600) / 60
    let s = total % 60
    if h > 0 {
      return String(format: "%d:%02d:%02d", h, m, s)
    }
    return String(format: "%02d:%02d", m, s)
  }

  static func bestQuality(_ qualities: [String]) -> String? {
    guard !qualities.isEmpty else { return nil }
    return qualities.sorted { qualityScore($0) > qualityScore($1) }.first
  }

  static func qualityScore(_ raw: String) -> Int {
    let digits = raw.filter(\.isNumber)
    return Int(digits) ?? -1
  }

  static func viewCount(_ count: Int) -> String {
    "조회 \(count)회"
  }

  static func relativeTime(from createdAt: String, now: Date = .init()) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let parsed = formatter.date(from: createdAt) ?? {
      formatter.formatOptions = [.withInternetDateTime]
      return formatter.date(from: createdAt)
    }()
    guard let parsed else { return "" }
    let interval = max(0, now.timeIntervalSince(parsed))
    let minutes = Int(interval / 60)
    let hours = minutes / 60
    let days = hours / 24
    let months = days / 30
    let years = days / 365
    if years > 0 { return "\(years)년 전" }
    if months > 0 { return "\(months)개월 전" }
    if days > 0 { return "\(days)일 전" }
    if hours > 0 { return "\(hours)시간 전" }
    if minutes > 0 { return "\(minutes)분 전" }
    return "방금"
  }

  static func cardSubMeta(for video: VideoResponseDTO) -> String {
    "\(viewCount(video.viewCount)) · \(relativeTime(from: video.createdAt))"
  }

  static func detailChannelMeta(for video: VideoResponseDTO) -> String {
    "Tone Atelier · \(viewCount(video.viewCount)) · \(relativeTime(from: video.createdAt))"
  }
}
