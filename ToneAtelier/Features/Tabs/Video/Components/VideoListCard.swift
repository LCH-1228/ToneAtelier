//
//  VideoListCard.swift
//  ToneAtelier
//
//  Created by Codex on 5/5/26.
//

import SwiftUI

struct VideoListCard: View {
  let video: VideoResponseDTO
  let watchProgress: Double
  let onTap: () -> Void
  let onLikeTap: () -> Void

  private static let cardCornerRadius: CGFloat = 12
  private static let thumbnailHeight: CGFloat = 197

  var body: some View {
    Button(action: onTap) {
      VStack(alignment: .leading, spacing: 12) {
        thumbnailWrap
        infoRow
          .padding(.horizontal, 12)
      }
      .padding(.bottom, 12)
      .background(AppTheme.blackTurquoise)
      .clipShape(RoundedRectangle(cornerRadius: Self.cardCornerRadius, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: Self.cardCornerRadius, style: .continuous)
          .strokeBorder(Color(hex: 0x222222), lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("video_card_\(video.videoID)")
  }

  private var thumbnailWrap: some View {
    GeometryReader { proxy in
      ZStack(alignment: .topLeading) {
        ChatImageView(
          path: video.thumbnailURL,
          baseURL: nil,
          shape: .roundedRect(cornerRadius: 0),
          placeholder: .photo,
          contentMode: .fill
        )
        .frame(width: proxy.size.width, height: Self.thumbnailHeight)

        LinearGradient(
          colors: [Color.black.opacity(0), Color.black.opacity(0.8)],
          startPoint: .top,
          endPoint: .bottom
        )
        .frame(width: proxy.size.width, height: 52)
        .frame(maxHeight: .infinity, alignment: .bottom)

        durationBadge
          .padding(.top, Self.thumbnailHeight - 30)
          .padding(.leading, proxy.size.width - 60)

        progressBar(width: proxy.size.width)
          .frame(maxHeight: .infinity, alignment: .bottom)
      }
      .frame(width: proxy.size.width, height: Self.thumbnailHeight)
      .clipped()
    }
    .frame(height: Self.thumbnailHeight)
  }

  private var durationBadge: some View {
    Text(VideoMetaFormatter.formatDuration(video.duration))
      .pretendard(.caption2Bold)
      .foregroundStyle(.white)
      .padding(.horizontal, 6)
      .padding(.vertical, 4)
      .background(Color.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 4))
  }

  private func progressBar(width: CGFloat) -> some View {
    let progress = max(0, min(1, watchProgress))
    return ZStack(alignment: .leading) {
      Rectangle()
        .fill(Color.white.opacity(0.33))
        .frame(width: width, height: 3)
      Rectangle()
        .fill(Color(hex: 0xFF0033))
        .frame(width: width * progress, height: 3)
    }
    .frame(height: 3)
  }

  private var infoRow: some View {
    HStack(alignment: .top, spacing: 12) {
      VideoOfficialAvatar(size: 36)
      textColumn
      Spacer(minLength: 0)
      likeActions
    }
  }

  private var textColumn: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(video.title)
        .pretendard(.body3Bold)
        .foregroundStyle(AppTheme.gray30)
        .lineLimit(2)
        .multilineTextAlignment(.leading)
      Text("Tone Atelier")
        .pretendard(.caption2Bold)
        .foregroundStyle(Color(hex: 0xB9CBD1))
        .lineLimit(1)
      Text(VideoMetaFormatter.cardSubMeta(for: video))
        .pretendard(.caption2Bold)
        .foregroundStyle(Color(hex: 0x8F8F94))
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var likeActions: some View {
    Button(action: onLikeTap) {
      HStack(spacing: 6) {
        Text("\(video.likeCount)")
          .pretendard(.caption2Bold)
          .foregroundStyle(AppTheme.gray30)
        Image(systemName: video.isLiked ? "heart.fill" : "heart")
          .font(AppTheme.symbol(size: 16, weight: .regular))
          .foregroundStyle(video.isLiked ? Color(hex: 0xFF6B7A) : AppTheme.gray60)
      }
      .padding(.vertical, 2)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(video.isLiked ? "좋아요 취소" : "좋아요")
    .accessibilityIdentifier("video_card_like_\(video.videoID)")
  }
}
