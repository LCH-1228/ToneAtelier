//
//  ChatDateUtilities.swift
//  ToneAtelier
//
//  Created by LCH on 4/29/26.
//

import Foundation

/// 채팅 도메인에서 사용하는 ISO8601 날짜 포맷 변환 유틸리티.
/// 서버 응답 형식: `9999-05-06T06:04:52.542Z` (fractional seconds 포함).
/// 단계 2/3에서 공유하기 위해 enum 네임스페이스로 둔다.
nonisolated enum ChatDateUtilities {
  /// fractional seconds를 포함하는 ISO8601 포맷터 (서버 표준).
  private static let iso8601Fractional: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  /// fractional seconds가 없는 케이스 fallback.
  private static let iso8601Plain: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()

  /// ISO8601 문자열 → Date. 실패 시 `Date(timeIntervalSince1970: 0)`.
  /// 디코딩 실패는 정렬에 영향을 주지 않도록 명시적으로 epoch로 떨어뜨린다.
  static func parseISO8601(_ string: String) -> Date {
    if let date = iso8601Fractional.date(from: string) {
      return date
    }
    if let date = iso8601Plain.date(from: string) {
      return date
    }
    return Date(timeIntervalSince1970: 0)
  }

  /// Optional 변환. nil/실패 모두 nil을 반환한다 (epoch fallback 없음).
  static func parseISO8601Optional(_ string: String?) -> Date? {
    guard let string else { return nil }
    if let date = iso8601Fractional.date(from: string) {
      return date
    }
    return iso8601Plain.date(from: string)
  }

  /// Date → ISO8601 문자열. 페이지네이션 `next` 파라미터 등에 사용.
  static func formatISO8601(_ date: Date) -> String {
    iso8601Fractional.string(from: date)
  }

  /// 채팅방 리스트 행에 표시할 시간 텍스트.
  /// - 오늘: `오후 3:42`
  /// - 어제: `어제`
  /// - 같은 해: `5월 6일`
  /// - 그 외: `9999. 5. 6.`
  static func relativeListTimeText(for date: Date, now: Date = Date()) -> String {
    let calendar = Calendar.current
    if calendar.isDateInToday(date) {
      return RelativeListFormatters.todayTime.string(from: date)
    }
    if calendar.isDateInYesterday(date) {
      return "어제"
    }
    if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
      return RelativeListFormatters.sameYear.string(from: date)
    }
    return RelativeListFormatters.otherYear.string(from: date)
  }
}

/// `relativeListTimeText`에서 사용하는 DateFormatter를 정적으로 보관한다.
/// DateFormatter 생성/설정 비용은 호출당 비교적 비싸기 때문에 캐싱한다.
nonisolated private enum RelativeListFormatters {
  static let todayTime: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "a h:mm"
    return formatter
  }()

  static let sameYear: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "M월 d일"
    return formatter
  }()

  static let otherYear: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateStyle = .short
    return formatter
  }()
}
