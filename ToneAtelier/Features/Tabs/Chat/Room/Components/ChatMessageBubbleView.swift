//
//  ChatMessageBubbleView.swift
//  ToneAtelier
//
//  Created by LCH on 4/29/26.
//

import SwiftUI

/// 카카오톡 스타일 메시지 셀.
/// - 본인: 우측 정렬, 강조색 버블, 흰 텍스트.
/// - 상대: 좌측 정렬, 어두운 그레이 버블, 프로필/닉네임은 첫 메시지에서만 표시.
struct ChatMessageBubbleView: View {
  let message: ChatMessage
  let isMine: Bool
  /// 같은 sender의 연속 메시지에서 첫 번째인지 (프로필/닉네임 표시 여부).
  let showsHeader: Bool
  /// 같은 sender 그룹의 마지막 메시지인지 (시간 표시 여부).
  let showsTimestamp: Bool
  let baseURL: URL?

  var body: some View {
    HStack(alignment: .bottom, spacing: 6) {
      if isMine {
        Spacer(minLength: 48)
        timestampLabel
        bubble
      } else {
        avatar
        VStack(alignment: .leading, spacing: 4) {
          if showsHeader {
            Text(message.sender.nick)
              .font(HomeTheme.pretendard(size: 12, weight: .medium))
              .foregroundStyle(HomeTheme.gray60)
          }
          HStack(alignment: .bottom, spacing: 6) {
            bubble
            timestampLabel
          }
        }
        Spacer(minLength: 48)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, showsHeader ? 6 : 2)
  }

  // MARK: - Subviews

  @ViewBuilder
  private var avatar: some View {
    if isMine {
      EmptyView()
    } else if showsHeader {
      profileImage
        .frame(width: 32, height: 32)
        .clipShape(Circle())
    } else {
      // 프로필이 표시되지 않는 연속 메시지에서도 좌측 정렬 일관성을 위해 자리만 차지.
      Color.clear.frame(width: 32, height: 32)
    }
  }

  @ViewBuilder
  private var profileImage: some View {
    if let url = profileImageURL {
      AsyncImage(url: url) { phase in
        switch phase {
        case let .success(image):
          image.resizable().scaledToFill()
        default:
          avatarPlaceholder
        }
      }
    } else {
      avatarPlaceholder
    }
  }

  private var avatarPlaceholder: some View {
    ZStack {
      Circle().fill(HomeTheme.deepTurquoise)
      Image(systemName: "person.fill")
        .foregroundStyle(HomeTheme.gray60)
        .font(.system(size: 16))
    }
  }

  @ViewBuilder
  private var bubble: some View {
    VStack(alignment: isMine ? .trailing : .leading, spacing: 6) {
      if let files = message.files, !files.isEmpty {
        attachmentsView(files: files)
      }
      if let content = message.content, !content.isEmpty {
        Text(content)
          .font(HomeTheme.pretendard(size: 15, weight: .regular))
          .foregroundStyle(.white)
          .multilineTextAlignment(.leading)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 9)
    .background(bubbleBackground)
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
  }

  private var bubbleBackground: Color {
    isMine ? HomeTheme.brightTurquoise : HomeTheme.deepTurquoise
  }

  @ViewBuilder
  private var timestampLabel: some View {
    if showsTimestamp {
      // SwiftUI Text(date, format:) + ko_KR locale로 formatter 객체 보관 없이 시간 렌더링.
      // `.dateTime.hour().minute()` 한국어 locale에서 "오후 3:42" 형식을 자동으로 반환한다.
      Text(ChatDateUtilities.parseISO8601(message.createdAt), format: .dateTime.hour().minute())
        .environment(\.locale, Locale(identifier: "ko_KR"))
        .font(HomeTheme.pretendard(size: 11, weight: .regular))
        .foregroundStyle(HomeTheme.gray60)
    } else {
      EmptyView()
    }
  }

  // MARK: - Attachments

  @ViewBuilder
  private func attachmentsView(files: [String]) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      ForEach(files, id: \.self) { path in
        attachmentCell(for: path)
      }
    }
  }

  @ViewBuilder
  private func attachmentCell(for path: String) -> some View {
    if path.hasSuffix(".pdf") {
      pdfCell(path: path)
    } else if let url = absoluteURL(for: path) {
      AsyncImage(url: url) { phase in
        switch phase {
        case let .success(image):
          image.resizable().scaledToFit()
        case .failure:
          imagePlaceholder
        case .empty:
          imagePlaceholder
        @unknown default:
          imagePlaceholder
        }
      }
      .frame(maxWidth: 220, maxHeight: 220)
      .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    } else {
      imagePlaceholder
    }
  }

  private var imagePlaceholder: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(HomeTheme.blackTurquoise)
      Image(systemName: "photo")
        .foregroundStyle(HomeTheme.gray60)
    }
    .frame(width: 160, height: 120)
  }

  private func pdfCell(path: String) -> some View {
    HStack(spacing: 8) {
      Image(systemName: "doc.richtext")
        .foregroundStyle(HomeTheme.gray30)
      Text(displayName(for: path))
        .font(HomeTheme.pretendard(size: 13, weight: .medium))
        .foregroundStyle(HomeTheme.gray30)
        .lineLimit(1)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(HomeTheme.blackTurquoise)
    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
  }

  // MARK: - Derived

  private var profileImageURL: URL? {
    absoluteURL(for: message.sender.profileImage)
  }

  private func absoluteURL(for path: String?) -> URL? {
    guard let path, !path.isEmpty else { return nil }
    if let direct = URL(string: path), direct.scheme != nil {
      return direct
    }
    guard let baseURL else { return nil }
    let normalized = path.hasPrefix("/") ? String(path.dropFirst()) : path
    return URL(string: normalized, relativeTo: baseURL)?.absoluteURL
  }

  private func displayName(for path: String) -> String {
    if let url = URL(string: path) {
      return url.lastPathComponent
    }
    return path
  }
}
