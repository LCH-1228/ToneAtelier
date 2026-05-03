//
//  PostCardView.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//
//  Pencil node: TTGh7 (Post 메인 카드). 영상 배지 eo5mt 포함.
//

import SwiftUI

struct PostCardView: View {
  let post: PostSummaryResponseDTO
  let cardAction: () -> Void
  let likeAction: () -> Void
  let authorAction: () -> Void
  let moreAction: () -> Void

  // SwiftUI body는 MainActor에서만 호출되므로 아래 formatter들은 단일 스레드 접근만 발생한다.
  // Sendable 미선언 타입을 static let에 두기 위해 nonisolated(unsafe)로 명시.

  /// 매 렌더마다 인스턴스화하지 않도록 정적 캐시.
  nonisolated(unsafe) private static let isoFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  /// fractional seconds 없는 응답 fallback용.
  nonisolated(unsafe) private static let isoFormatterNoFraction: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()

  /// 한국어 상대시간 포맷터. locale/style 고정.
  nonisolated(unsafe) private static let relativeFormatter: RelativeDateTimeFormatter = {
    let formatter = RelativeDateTimeFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.unitsStyle = .short
    return formatter
  }()

  var body: some View {
    Button(action: cardAction) {
      VStack(alignment: .leading, spacing: 0) {
        mediaThumbnail
          .frame(height: 280)
          .frame(maxWidth: .infinity)
          .clipped()

        VStack(alignment: .leading, spacing: 6) {
          metaLine
          titleText
          bodyText
          actionsRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(AppTheme.blackTurquoise)
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .frame(maxWidth: .infinity)
  }

  private var mediaThumbnail: some View {
    Color.clear
      .overlay {
        ChatImageView(
          path: post.files.first,
          baseURL: nil,
          shape: .roundedRect(cornerRadius: 0)
        )
      }
      .overlay(alignment: .topLeading) {
        if isVideo {
          videoBadge
            .padding(12)
        }
      }
      .overlay {
        if isVideo {
          Image(systemName: "play.circle.fill")
            .font(AppTheme.symbol(size: 44, weight: .regular))
            .foregroundStyle(.white.opacity(0.95))
            .allowsHitTesting(false)
        }
      }
      .clipped()
  }

  private var videoBadge: some View {
    Text("영상")
      .font(AppTheme.pretendard(size: 11, weight: .bold))
      .foregroundStyle(AppTheme.gray15)
      .padding(.horizontal, 8)
      .frame(height: 22)
      .background(AppTheme.deepTurquoise.opacity(0.85))
      .clipShape(Capsule())
  }

  private var metaLine: some View {
    HStack(spacing: 6) {
      Button(action: authorAction) {
        Text(metaText)
          .font(AppTheme.pretendard(size: 12, weight: .medium))
          .foregroundStyle(AppTheme.gray60)
          .lineLimit(1)
          .truncationMode(.tail)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)

      Spacer(minLength: 0)

      Button(action: moreAction) {
        Image(systemName: "ellipsis")
          .font(AppTheme.symbol(size: 16, weight: .semibold))
          .foregroundStyle(AppTheme.gray60)
          .frame(width: 24, height: 24)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("더보기")
    }
  }

  private var titleText: some View {
    Text(post.title)
      .font(AppTheme.pretendard(size: 16, weight: .bold))
      .foregroundStyle(AppTheme.gray30)
      .lineLimit(2)
      .multilineTextAlignment(.leading)
  }

  private var bodyText: some View {
    Text(post.content)
      .font(AppTheme.pretendard(size: 13, weight: .regular))
      .foregroundStyle(AppTheme.gray60)
      .lineLimit(3)
      .multilineTextAlignment(.leading)
      .padding(.top, 2)
  }

  private var actionsRow: some View {
    HStack(spacing: 16) {
      Button(action: likeAction) {
        HStack(spacing: 6) {
          Image(systemName: post.isLike ? "heart.fill" : "heart")
            .font(AppTheme.symbol(size: 16, weight: .regular))
            .foregroundStyle(post.isLike ? AppTheme.brightTurquoise : AppTheme.gray60)
          Text(formattedCount(post.likeCount))
            .font(AppTheme.pretendard(size: 13, weight: .medium))
            .foregroundStyle(AppTheme.gray60)
        }
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(post.isLike ? "좋아요 취소" : "좋아요")

      // 댓글 카운트는 PostSummaryResponseDTO에 포함되지 않아 정확한 수를 알 수 없음.
      // 부정확한 0 노출 대신 자리를 숨김. 상세 응답에 commentCount가 포함되면 그때 복원.

      Spacer(minLength: 0)
    }
    .padding(.top, 8)
  }

  private var metaText: String {
    let category = post.category.isEmpty ? "기타" : post.category
    let nickname = post.creator.nick.isEmpty ? "익명" : post.creator.nick
    let time = relativeTime(from: post.createdAt)
    return "\(category) · \(nickname) · \(time)"
  }

  private var isVideo: Bool {
    guard let firstFile = post.files.first else { return false }
    let lower = firstFile.lowercased()
    return Self.videoExtensions.contains(where: { lower.hasSuffix($0) })
  }

  private static let videoExtensions: [String] = [".mp4", ".mov", ".m4v"]

  private func formattedCount(_ value: Double) -> String {
    let intValue = Int(value)
    if intValue >= 1000 {
      let truncated = Double(intValue) / 1000
      return String(format: "%.1fK", truncated)
    }
    return "\(intValue)"
  }

  private func relativeTime(from iso: String) -> String {
    let date = Self.isoFormatter.date(from: iso) ?? Self.isoFormatterNoFraction.date(from: iso)
    guard let date else { return "" }
    let interval = Date().timeIntervalSince(date)
    return Self.relativeFormatter.localizedString(fromTimeInterval: -max(interval, 0))
  }
}

#Preview {
  PostCardView(
    post: PostSummaryResponseDTO(
      postID: "preview",
      category: "푸드",
      title: "비 내린 오후의 색을 영상과 사진으로 남겼어요",
      content: "사진과 짧은 영상이 함께 담긴 게시글입니다. 아래로 스크롤하면 더 많은 게시글을 볼 수 있어요.",
      geolocation: GeolocationDTO(longitude: 0, latitude: 0),
      creator: UserInfoResponseDTO(
        userID: "u1",
        nick: "김새싹",
        name: nil,
        introduction: nil,
        profileImage: nil,
        hashTags: nil
      ),
      files: ["dummy.jpg"],
      isLike: false,
      likeCount: 128,
      createdAt: "2026-05-03T12:00:00Z",
      updatedAt: "2026-05-03T12:00:00Z"
    ),
    cardAction: {},
    likeAction: {},
    authorAction: {},
    moreAction: {}
  )
  .padding(20)
  .background(AppTheme.background)
  .preferredColorScheme(.dark)
}
