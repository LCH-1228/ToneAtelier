//
//  PostCardView.swift
//  ToneAtelier
//

import SwiftUI

struct PostCardView: View {
  let post: PostSummaryResponseDTO
  let isOwn: Bool
  let cardAction: () -> Void
  let likeAction: () -> Void
  let authorAction: () -> Void
  let editAction: () -> Void
  let deleteAction: () -> Void

  nonisolated(unsafe) private static let isoFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  nonisolated(unsafe) private static let isoFormatterNoFraction: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()

  nonisolated(unsafe) private static let relativeFormatter: RelativeDateTimeFormatter = {
    let formatter = RelativeDateTimeFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.unitsStyle = .short
    return formatter
  }()

  private var firstFileIsVideo: Bool {
    guard let first = post.files.first else { return false }
    return MediaPathClassifier.isVideo(first)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      mediaSection
        .frame(height: 168)
        .frame(maxWidth: .infinity)
        .clipped()

      VStack(alignment: .leading, spacing: 0) {
        authorRow
          .padding(.top, 16)
        titleText
          .padding(.top, 8)
        bodyText
          .padding(.top, 6)
        actionsRow
          .padding(.top, 8)
      }
      .padding(.horizontal, 14)
      .padding(.bottom, 14)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(AppTheme.blackTurquoise)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .contentShape(.rect)
    .onTapGesture {
      cardAction()
    }
    .frame(maxWidth: .infinity)
  }

  @ViewBuilder
  private var mediaSection: some View {
    let count = post.files.count
    ZStack(alignment: .topLeading) {
      if count >= 3 {
        HStack(spacing: 2) {
          mediaTile(at: 0)
          VStack(spacing: 2) {
            mediaTile(at: 1)
            mediaTile(at: 2)
          }
          .frame(width: 134)
        }
      } else if count == 2 {
        HStack(spacing: 2) {
          mediaTile(at: 0)
          mediaTile(at: 1)
            .frame(width: 134)
        }
      } else {
        mediaTile(at: 0)
      }

      categoryChip
        .padding(14)
    }
  }

  @ViewBuilder
  private func mediaTile(at index: Int) -> some View {
    if let path = post.files[safe: index] {
      Color.clear
        .overlay {
          if MediaPathClassifier.isVideo(path) {
            VideoMediaView(
              path: path,
              shape: .roundedRect(cornerRadius: 0),
              inlinePlaybackEnabled: true
            )
          } else {
            ChatImageView(
              path: path,
              baseURL: nil,
              shape: .roundedRect(cornerRadius: 0)
            )
          }
        }
        .clipped()
    } else {
      AppTheme.deepTurquoise
    }
  }

  private var categoryChip: some View {
    let label = post.category.isEmpty ? "기타" : post.category
    return Text(label)
      .pretendard(.captionMeta)
      .foregroundStyle(AppTheme.gray30)
      .padding(.horizontal, 12)
      .frame(height: 26)
      .background(AppTheme.brightTurquoise.opacity(0.8))
      .clipShape(Capsule())
  }

  private var authorRow: some View {
    HStack(spacing: 8) {
      Button(action: authorAction) {
        HStack(spacing: 8) {
          ChatImageView(
            path: post.creator.profileImage,
            baseURL: nil,
            shape: .circle
          )
          .frame(width: 24, height: 24)
          .overlay { Circle().stroke(AppTheme.brightTurquoise, lineWidth: 1) }

          Text(metaText)
            .pretendard(.captionMeta)
            .foregroundStyle(AppTheme.gray75)
            .lineLimit(1)
            .truncationMode(.tail)
        }
        .contentShape(.rect)
      }
      .buttonStyle(.plain)

      Spacer(minLength: 0)

      if isOwn {
        Menu {
          Button("수정", action: editAction)
          Button("삭제", role: .destructive, action: deleteAction)
        } label: {
          Image(systemName: "ellipsis")
            .font(AppTheme.symbol(size: 20, weight: .regular))
            .foregroundStyle(AppTheme.gray75)
            .frame(width: 24, height: 24)
            .contentShape(.rect)
        }
        .accessibilityLabel("더보기")
      }
    }
  }

  private var titleText: some View {
    Text(post.title)
      .pretendard(.body1)
      .foregroundStyle(AppTheme.gray30)
      .lineLimit(2)
      .multilineTextAlignment(.leading)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var bodyText: some View {
    Text(post.content)
      .pretendard(.caption1)
      .foregroundStyle(AppTheme.gray60)
      .lineLimit(2)
      .multilineTextAlignment(.leading)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var actionsRow: some View {
    HStack(spacing: 14) {
      Button(action: likeAction) {
        HStack(spacing: 6) {
          Image(systemName: post.isLike ? "heart.fill" : "heart")
            .font(AppTheme.symbol(size: 18, weight: .regular))
            .foregroundStyle(post.isLike ? AppTheme.brightTurquoise : AppTheme.gray60)
          Text(formattedCount(post.likeCount))
            .pretendard(.captionMeta)
            .foregroundStyle(AppTheme.gray60)
        }
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(post.isLike ? "좋아요 취소" : "좋아요")

      Spacer(minLength: 0)
    }
  }

  private var metaText: String {
    let nickname = post.creator.nick.isEmpty ? "익명" : post.creator.nick
    let time = relativeTime(from: post.createdAt)
    return "\(nickname) · \(time)"
  }

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

private extension Array {
  subscript(safe index: Int) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}
