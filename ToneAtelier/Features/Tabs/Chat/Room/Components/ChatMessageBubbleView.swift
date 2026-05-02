//
//  ChatMessageBubbleView.swift
//  ToneAtelier
//
//  Created by LCH on 4/29/26.
//

import SwiftUI

/// 카카오톡 스타일 메시지 셀.
///
/// 한 메시지에 텍스트와 사진이 모두 있는 경우 두 요소를 시각적으로 분리한다.
/// - 사진은 자체 박스(둥근 모서리만 적용, 별도 버블 배경 없음).
/// - 텍스트는 별도 둥근 버블에 표시.
/// - 같은 sender 연속 그룹이라면 헤더(닉네임/아바타)는 사진/텍스트 묶음 전체에 한 번만 표시.
///
/// 사진이 여러 장일 때 카카오톡식 그리드(1/2/3-4/5장)로 배치한다. 5장 초과는 명세상 발생하지 않으므로
/// 입력 검증과 일관되게 5장까지만 분기한다.
struct ChatMessageBubbleView: View {
  let message: ChatMessage
  let isMine: Bool
  /// 같은 sender의 연속 메시지에서 첫 번째인지 (프로필/닉네임 표시 여부).
  let showsHeader: Bool
  /// 같은 sender 그룹의 마지막 메시지인지 (시간 표시 여부).
  let showsTimestamp: Bool
  let baseURL: URL?
  /// PDF 셀 탭 콜백. 파일 path를 그대로 부모(ChatRoomFeature)에 전달한다.
  let onPDFTapped: (String) -> Void
  /// 진행 중인 PDF fetch의 path. 셀의 도넛 progress 표시 + tap 비활성화 용도.
  let preparingPDFPath: String?

  var body: some View {
    HStack(alignment: .bottom, spacing: 6) {
      if isMine {
        Spacer(minLength: 48)
        timestampLabel
        contentColumn
      } else {
        avatar
        VStack(alignment: .leading, spacing: 4) {
          if showsHeader {
            Text(message.sender.nick)
              .font(AppTheme.pretendard(size: 12, weight: .medium))
              .foregroundStyle(AppTheme.gray60)
          }
          HStack(alignment: .bottom, spacing: 6) {
            contentColumn
            timestampLabel
          }
        }
        Spacer(minLength: 48)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, showsHeader ? 6 : 2)
  }

  // MARK: - Avatar

  @ViewBuilder
  private var avatar: some View {
    if isMine {
      EmptyView()
    } else if showsHeader {
      ChatImageView(
        path: message.sender.profileImage,
        baseURL: baseURL,
        shape: .circle,
        placeholder: .person
      )
      .frame(width: 32, height: 32)
    } else {
      // 프로필이 표시되지 않는 연속 메시지에서도 좌측 정렬 일관성을 위해 자리만 차지.
      Color.clear.frame(width: 32, height: 32)
    }
  }

  // MARK: - Content Column

  /// 사진 그리드와 텍스트 버블을 세로로 쌓는 컬럼. 같은 sender 그룹이라도 각 요소는
  /// 자체 시각 단위를 갖는다. 카톡과 마찬가지로 사진은 buble 배경 없이 모서리만 둥근 박스.
  @ViewBuilder
  private var contentColumn: some View {
    VStack(alignment: isMine ? .trailing : .leading, spacing: 6) {
      if let images = imageFiles, !images.isEmpty {
        ChatImageGridView(paths: images, baseURL: baseURL)
      }
      if let pdfs = pdfFiles, !pdfs.isEmpty {
        ForEach(pdfs, id: \.self) { path in
          pdfCell(path: path)
        }
      }
      if let content = message.content, !content.isEmpty {
        textBubble(content: content)
      }
    }
  }

  // MARK: - Text bubble

  private func textBubble(content: String) -> some View {
    Text(content)
      .font(AppTheme.pretendard(size: 15, weight: .regular))
      .foregroundStyle(.white)
      .multilineTextAlignment(.leading)
      .fixedSize(horizontal: false, vertical: true)
      .padding(.horizontal, 12)
      .padding(.vertical, 9)
      .background(isMine ? AppTheme.brightTurquoise : AppTheme.deepTurquoise)
      .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
  }

  // MARK: - PDF cell

  /// PDF 첨부 셀. 탭하면 부모로 path를 전달해 풀스크린 미리보기를 띄운다.
  /// 진행 중일 때는 dim + ProgressView 오버레이로 시각적 피드백을 제공한다.
  private func pdfCell(path: String) -> some View {
    Button { onPDFTapped(path) } label: {
      HStack(spacing: 8) {
        Image(systemName: "doc.richtext")
          .foregroundStyle(AppTheme.gray30)
        Text(displayName(for: path))
          .font(AppTheme.pretendard(size: 13, weight: .medium))
          .foregroundStyle(AppTheme.gray30)
          .lineLimit(1)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
      .background(AppTheme.blackTurquoise)
      .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
      .overlay {
        if preparingPDFPath == path {
          ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
              .fill(Color.black.opacity(0.4))
            ProgressView()
              .progressViewStyle(.circular)
              .tint(.white)
          }
        }
      }
    }
    .buttonStyle(.plain)
    .disabled(preparingPDFPath == path)
    .accessibilityLabel("PDF 미리보기")
  }

  // MARK: - Timestamp

  @ViewBuilder
  private var timestampLabel: some View {
    if showsTimestamp {
      // SwiftUI Text(date, format:) + ko_KR locale로 formatter 객체 보관 없이 시간 렌더링.
      // `.dateTime.hour().minute()` 한국어 locale에서 "오후 3:42" 형식을 자동으로 반환한다.
      Text(ChatDateUtilities.parseISO8601(message.createdAt), format: .dateTime.hour().minute())
        .environment(\.locale, Locale(identifier: "ko_KR"))
        .font(AppTheme.pretendard(size: 11, weight: .regular))
        .foregroundStyle(AppTheme.gray60)
    } else {
      EmptyView()
    }
  }

  // MARK: - Derived

  private var imageFiles: [String]? {
    guard let files = message.files else { return nil }
    let images = files.filter { !$0.lowercased().hasSuffix(".pdf") }
    return images.isEmpty ? nil : images
  }

  private var pdfFiles: [String]? {
    guard let files = message.files else { return nil }
    let pdfs = files.filter { $0.lowercased().hasSuffix(".pdf") }
    return pdfs.isEmpty ? nil : pdfs
  }

  private func displayName(for path: String) -> String {
    if let url = URL(string: path) {
      return url.lastPathComponent
    }
    return path
  }
}

// MARK: - Preview

#Preview("KakaoTalk-style grid 1/2/3/4/5") {
  let me = ChatUserSummary(
    user_id: "me",
    nick: "나",
    name: nil,
    introduction: nil,
    profileImage: nil,
    hashTags: nil
  )
  let other = ChatUserSummary(
    user_id: "other",
    nick: "토니",
    name: nil,
    introduction: nil,
    profileImage: nil,
    hashTags: nil
  )

  func sample(id: String, sender: ChatUserSummary, files: [String]?, content: String?) -> ChatMessage {
    ChatMessage(
      chat_id: id,
      room_id: "preview",
      content: content,
      createdAt: "2026-04-29T08:30:00.000Z",
      updatedAt: nil,
      sender: sender,
      files: files
    )
  }

  return ZStack {
    AppTheme.background.ignoresSafeArea()
    ScrollView {
      VStack(spacing: 12) {
        ChatMessageBubbleView(
          message: sample(id: "1", sender: other, files: ["/v1/data/1.jpg"], content: nil),
          isMine: false, showsHeader: true, showsTimestamp: true,
          baseURL: URL(string: "https://example.com/"),
          onPDFTapped: { _ in }, preparingPDFPath: nil
        )
        ChatMessageBubbleView(
          message: sample(id: "2", sender: other, files: ["/v1/data/1.jpg", "/v1/data/2.jpg"], content: nil),
          isMine: false, showsHeader: true, showsTimestamp: true,
          baseURL: URL(string: "https://example.com/"),
          onPDFTapped: { _ in }, preparingPDFPath: nil
        )
        ChatMessageBubbleView(
          message: sample(id: "3", sender: me, files: ["/v1/data/1.jpg", "/v1/data/2.jpg", "/v1/data/3.jpg"], content: "사진 3장이에요"),
          isMine: true, showsHeader: true, showsTimestamp: true,
          baseURL: URL(string: "https://example.com/"),
          onPDFTapped: { _ in }, preparingPDFPath: nil
        )
        ChatMessageBubbleView(
          message: sample(id: "4", sender: me, files: ["/v1/data/1.jpg", "/v1/data/2.jpg", "/v1/data/3.jpg", "/v1/data/4.jpg"], content: nil),
          isMine: true, showsHeader: true, showsTimestamp: true,
          baseURL: URL(string: "https://example.com/"),
          onPDFTapped: { _ in }, preparingPDFPath: nil
        )
        ChatMessageBubbleView(
          message: sample(id: "5", sender: other, files: ["/v1/data/1.jpg", "/v1/data/2.jpg", "/v1/data/3.jpg", "/v1/data/4.jpg", "/v1/data/5.jpg"], content: "다섯 장!"),
          isMine: false, showsHeader: true, showsTimestamp: true,
          baseURL: URL(string: "https://example.com/"),
          onPDFTapped: { _ in }, preparingPDFPath: nil
        )
        // PDF 첨부 케이스(아이들 / 진행 중) 두 가지 시나리오를 모두 노출.
        ChatMessageBubbleView(
          message: sample(id: "6", sender: other, files: ["/v1/data/report.pdf"], content: "참고 자료"),
          isMine: false, showsHeader: true, showsTimestamp: true,
          baseURL: URL(string: "https://example.com/"),
          onPDFTapped: { _ in }, preparingPDFPath: nil
        )
        ChatMessageBubbleView(
          message: sample(id: "7", sender: me, files: ["/v1/data/report.pdf"], content: nil),
          isMine: true, showsHeader: true, showsTimestamp: true,
          baseURL: URL(string: "https://example.com/"),
          onPDFTapped: { _ in }, preparingPDFPath: "/v1/data/report.pdf"
        )
      }
      .padding(.vertical, 16)
    }
  }
  .preferredColorScheme(.dark)
}
