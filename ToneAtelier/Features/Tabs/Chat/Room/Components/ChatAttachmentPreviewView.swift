//
//  ChatAttachmentPreviewView.swift
//  ToneAtelier
//
//  Created by LCH on 4/29/26.
//

import SwiftUI
import UIKit

/// 입력바 위쪽에 표시되는 가로 스크롤 첨부 미리보기.
/// 이미지: 썸네일. PDF: 아이콘 + 파일명. 각 셀 우측 상단에 X 버튼.
///
/// `isUploading`이 true이면 각 셀 위에 디밍(검은 50%) + 도넛(circular ProgressView)을 overlay 한다.
/// 업로드 중에는 X 제거 버튼도 비활성화하여 진행 중인 multipart 요청과의 정합성을 유지한다.
struct ChatAttachmentPreviewView: View {
  let attachments: [LocalAttachment]
  let isUploading: Bool
  let onRemove: (UUID) -> Void

  init(
    attachments: [LocalAttachment],
    isUploading: Bool = false,
    onRemove: @escaping (UUID) -> Void
  ) {
    self.attachments = attachments
    self.isUploading = isUploading
    self.onRemove = onRemove
  }

  var body: some View {
    if attachments.isEmpty {
      EmptyView()
    } else {
      // showsIndicators 매개변수는 deprecated. modern API `.scrollIndicators(.hidden)` 사용.
      ScrollView(.horizontal) {
        HStack(spacing: 8) {
          ForEach(attachments) { attachment in
            cell(for: attachment)
          }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
      }
      .scrollIndicators(.hidden)
      .frame(height: 88)
      .background(AppTheme.background)
    }
  }

  @ViewBuilder
  private func cell(for attachment: LocalAttachment) -> some View {
    ZStack(alignment: .topTrailing) {
      content(for: attachment)
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
          if isUploading {
            ZStack {
              RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black.opacity(0.5))
              ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
            }
          }
        }

      Button {
        onRemove(attachment.id)
      } label: {
        Image(systemName: "xmark.circle.fill")
          .font(AppTheme.symbol(size: 18, weight: .regular))
          .foregroundStyle(.white, Color.black.opacity(0.6))
      }
      .buttonStyle(.plain)
      .padding(4)
      .disabled(isUploading)
      .accessibilityLabel("첨부 제거")
    }
  }

  @ViewBuilder
  private func content(for attachment: LocalAttachment) -> some View {
    switch attachment.kind {
    case .image:
      let preferred = attachment.previewImage ?? attachment.data
      AttachmentImageCell(data: preferred)
    case .pdf:
      VStack(spacing: 4) {
        Image(systemName: "doc.richtext")
          .font(AppTheme.symbol(size: 22, weight: .regular))
          .foregroundStyle(AppTheme.gray30)
        Text(attachment.fileName)
          .pretendard(.caption3)
          .foregroundStyle(AppTheme.gray45)
          .lineLimit(2)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 4)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(AppTheme.blackTurquoise)
    }
  }

  private var placeholder: some View {
    ZStack {
      // hierarchical secondary 배경. 다크 테마와 자연스럽게 어울리도록 변경.
      Color.secondary.opacity(0.2)
      Image(systemName: "photo")
        .foregroundStyle(.white)
    }
  }
}

/// 첨부 이미지 셀. UIImage 디코딩을 `task(id:)`로 1회만 수행해
/// 부모 body 재평가에 따른 반복 디코딩 비용을 제거한다.
/// 디코딩 실패(드물지만 가능) 시 secondary 회색 배경 + photo 아이콘으로 폴백.
private struct AttachmentImageCell: View {
  let data: Data
  @State private var image: UIImage?

  var body: some View {
    Group {
      if let image {
        Image(uiImage: image)
          .resizable()
          .scaledToFill()
      } else {
        ZStack {
          Color.secondary.opacity(0.2)
          Image(systemName: "photo")
            .foregroundStyle(.white)
        }
      }
    }
    .task(id: data) {
      image = UIImage(data: data)
    }
  }
}
