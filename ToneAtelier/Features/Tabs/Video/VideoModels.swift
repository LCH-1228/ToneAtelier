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
    let ranked = qualities.sorted { lhs, rhs in
      qualityScore(lhs) > qualityScore(rhs)
    }
    return ranked.first
  }

  static func qualityScore(_ raw: String) -> Int {
    let digits = raw.filter(\.isNumber)
    return Int(digits) ?? -1
  }

  static func cardMeta(for video: VideoResponseDTO) -> String {
    var parts = [formatDuration(video.duration)]
    if let quality = bestQuality(video.availableQualities) {
      parts.append(quality)
    }
    parts.append("조회 \(video.viewCount)")
    return parts.joined(separator: " · ")
  }

  static func detailMeta(for video: VideoResponseDTO) -> String {
    "\(formatDuration(video.duration)) · 좋아요 \(video.likeCount) · 조회 \(video.viewCount)"
  }

  static func clock(current: TimeInterval, total: TimeInterval) -> String {
    "\(formatDuration(current)) / \(formatDuration(total))"
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

struct SubtitleCue: Equatable, Sendable, Identifiable {
  let id: Int
  let start: TimeInterval
  let end: TimeInterval
  let text: String
}

enum WebVTTParser {
  static func parse(_ raw: String) -> [SubtitleCue] {
    let normalized = raw.replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
    let blocks = normalized
      .components(separatedBy: "\n\n")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }

    var cues: [SubtitleCue] = []
    for (index, block) in blocks.enumerated() {
      guard let cue = parseBlock(block, fallbackID: index) else { continue }
      cues.append(cue)
    }
    return cues
  }

  private static func parseBlock(_ block: String, fallbackID: Int) -> SubtitleCue? {
    let lines = block.components(separatedBy: "\n")
    guard let timingLine = lines.first(where: { $0.contains("-->") }) else {
      return nil
    }
    let timingParts = timingLine.components(separatedBy: "-->")
    guard
      timingParts.count == 2,
      let start = parseTimestamp(timingParts[0]),
      let end = parseTimestamp(timingParts[1])
    else { return nil }

    let textLines = lines
      .drop(while: { !$0.contains("-->") })
      .dropFirst()
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
    guard !textLines.isEmpty else { return nil }

    return SubtitleCue(
      id: fallbackID,
      start: start,
      end: end,
      text: textLines.joined(separator: "\n")
    )
  }

  private static func parseTimestamp(_ raw: String) -> TimeInterval? {
    let trimmed = raw.trimmingCharacters(in: .whitespaces)
      .replacingOccurrences(of: ",", with: ".")
      .components(separatedBy: " ").first ?? ""
    let parts = trimmed.components(separatedBy: ":")
    guard !parts.isEmpty else { return nil }

    var hours: Double = 0
    var minutes: Double = 0
    var secondsString = ""
    switch parts.count {
    case 3:
      hours = Double(parts[0]) ?? 0
      minutes = Double(parts[1]) ?? 0
      secondsString = parts[2]
    case 2:
      minutes = Double(parts[0]) ?? 0
      secondsString = parts[1]
    case 1:
      secondsString = parts[0]
    default:
      return nil
    }
    let seconds = Double(secondsString) ?? 0
    return hours * 3600 + minutes * 60 + seconds
  }
}
