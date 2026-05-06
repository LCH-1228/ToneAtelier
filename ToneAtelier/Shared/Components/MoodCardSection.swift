//
//  MoodCardSection.swift
//  ToneAtelier
//
//  Created by Claude on 5/7/26.
//

import SwiftUI

struct MoodCardItem: Identifiable, Equatable, Sendable {
  let id: String
  let title: String
  let category: String?
  let author: String?
  let description: String?
  let metaText: String?
  let imageURL: String?
}

struct MoodCardSection: View {
  let title: String
  let items: [MoodCardItem]
  let emptyHeadline: String
  let emptyDescription: String?
  let viewAllAction: () -> Void
  let itemAction: (MoodCardItem.ID) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 0) {
        Text(title)
          .pretendard(.body1)
          .foregroundStyle(AppTheme.gray60)

        Spacer(minLength: 0)

        if !items.isEmpty {
          Button(action: viewAllAction) {
            Text("더보기")
              .pretendard(.body2)
              .foregroundStyle(AppTheme.brightTurquoise)
              .padding(.vertical, 8)
              .padding(.leading, 12)
              .contentShape(.rect)
          }
          .buttonStyle(.plain)
          .accessibilityLabel("\(title) 더보기")
        }
      }

      if items.isEmpty {
        emptyPlaceholder
      } else {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 12) {
            ForEach(items) { item in
              MoodCard(item: item) {
                itemAction(item.id)
              }
            }
          }
          .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
      }
    }
  }

  private var emptyPlaceholder: some View {
    VStack(alignment: .center, spacing: 6) {
      Text(emptyHeadline)
        .pretendard(.body2)
        .foregroundStyle(AppTheme.gray45)

      if let description = emptyDescription, !description.isEmpty {
        Text(description)
          .pretendard(.caption1)
          .foregroundStyle(AppTheme.gray60)
          .multilineTextAlignment(.center)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 24)
    .padding(.horizontal, 16)
    .background(AppTheme.blackTurquoise)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .strokeBorder(AppTheme.deepTurquoise, lineWidth: 1)
    }
  }
}

private struct MoodCard: View {
  let item: MoodCardItem
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack(alignment: .top, spacing: 12) {
        Group {
          if let url = item.imageURL, !url.isEmpty {
            CachedImageView(urlString: url)
              .scaledToFill()
              .frame(width: 100, height: 120)
              .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
          } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
              .fill(AppTheme.deepTurquoise)
              .frame(width: 100, height: 120)
          }
        }

        VStack(alignment: .leading, spacing: 6) {
          Text(item.title)
            .mulgyeol(.body1)
            .foregroundStyle(AppTheme.gray30)
            .lineLimit(1)

          if let category = item.category, !category.isEmpty {
            Text(category)
              .pretendard(.caption1)
              .foregroundStyle(AppTheme.gray60)
              .padding(.horizontal, 8)
              .padding(.vertical, 3)
              .background(AppTheme.deepTurquoise, in: Capsule())
          }

          if let author = item.author, !author.isEmpty {
            Text(author)
              .pretendard(.body3Bold)
              .foregroundStyle(AppTheme.gray75)
              .lineLimit(1)
          }

          if let description = item.description, !description.isEmpty {
            Text(description)
              .pretendard(.captionParagraph)
              .foregroundStyle(AppTheme.gray60)
              .lineLimit(2)
              .multilineTextAlignment(.leading)
          }

          Spacer(minLength: 0)

          if let metaText = item.metaText, !metaText.isEmpty {
            Text(metaText)
              .pretendard(.captionMeta)
              .foregroundStyle(AppTheme.gray45)
              .lineLimit(1)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(12)
      .frame(width: 320, height: 144, alignment: .top)
      .background(AppTheme.blackTurquoise)
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .strokeBorder(AppTheme.deepTurquoise, lineWidth: 1)
      }
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
  }
}
