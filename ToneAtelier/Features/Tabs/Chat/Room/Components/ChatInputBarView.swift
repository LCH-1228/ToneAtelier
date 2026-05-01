//
//  ChatInputBarView.swift
//  ToneAtelier
//
//  Created by LCH on 4/29/26.
//

import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// 카카오톡 스타일 입력바.
/// - 좌측 첨부 메뉴(사진/파일/카메라)
/// - 자동 높이 TextField (1...4 줄)
/// - 우측 전송 버튼 (canSend false 시 회색)
struct ChatInputBarView: View {
  @Binding var text: String
  let canSend: Bool
  let isSending: Bool
  /// Feature가 보유한 현재 첨부 개수. PhotosPicker의 `maxSelectionCount`를 동적으로 계산하고
  /// 한도 도달 시 첨부 메뉴를 비활성화하기 위해 사용된다(C2: 첨부 한도 동기화).
  let currentAttachmentCount: Int
  let onSend: () -> Void
  let onPhotosSelected: ([PhotosPickerItem]) -> Void
  let onFilesImported: ([URL]) -> Void

  @State private var photoSelections: [PhotosPickerItem] = []
  @State private var isPhotosPickerPresented = false
  @State private var isFileImporterPresented = false

  /// 한 번에 선택 가능한 첨부 한도 (Feature의 maxAttachments와 동일).
  private let maxAttachments = ChatRoomFeature.maxAttachments

  /// 잔여 슬롯. PhotosPicker는 0을 허용하지 않으므로 최소 1로 보정한다(메뉴 자체가 비활성화되어 진입 불가).
  private var remainingSlots: Int {
    max(0, maxAttachments - currentAttachmentCount)
  }
  private var photosPickerSelectionLimit: Int {
    max(1, remainingSlots)
  }
  private var isAttachmentLimitReached: Bool {
    remainingSlots == 0
  }

  var body: some View {
    HStack(alignment: .bottom, spacing: 8) {
      attachmentMenu
      messageField
      sendButton
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(AppTheme.background)
    .overlay(alignment: .top) {
      Rectangle()
        .fill(AppTheme.deepTurquoise)
        .frame(height: 0.5)
    }
    .fileImporter(
      isPresented: $isFileImporterPresented,
      allowedContentTypes: [.pdf],
      allowsMultipleSelection: true
    ) { result in
      switch result {
      case let .success(urls):
        onFilesImported(urls)
      case .failure:
        onFilesImported([])
      }
    }
    .photosPicker(
      isPresented: $isPhotosPickerPresented,
      selection: $photoSelections,
      maxSelectionCount: photosPickerSelectionLimit,
      matching: .images,
      photoLibrary: .shared()
    )
    .onChange(of: photoSelections) { _, newValue in
      guard !newValue.isEmpty else { return }
      let snapshot = newValue
      photoSelections = []
      onPhotosSelected(snapshot)
    }
  }

  // MARK: - Subviews

  private var attachmentMenu: some View {
    // Menu(_:systemImage:) 표준 형식 + .labelStyle(.iconOnly)로 시각적 동일성 유지.
    // tap target 44x44 (HIG 권장 최소값) 보장.
    Menu("첨부 추가", systemImage: "plus.circle") {
      photosMenuButton
      filesMenuButton
      // TODO: 카메라 촬영 추가
    }
    .labelStyle(.iconOnly)
    .font(.system(size: 26, weight: .regular))
    .foregroundStyle(isAttachmentLimitReached ? AppTheme.gray75 : AppTheme.gray45)
    .frame(width: 44, height: 44)
    .contentShape(Rectangle())
    .disabled(isAttachmentLimitReached)
  }

  private var photosMenuButton: some View {
    Button {
      isPhotosPickerPresented = true
    } label: {
      Label("사진", systemImage: "photo.on.rectangle")
    }
  }

  private var filesMenuButton: some View {
    Button {
      isFileImporterPresented = true
    } label: {
      Label("파일 (PDF)", systemImage: "doc")
    }
  }

  private var messageField: some View {
    TextField(
      "메시지 입력",
      text: $text,
      axis: .vertical
    )
    .font(AppTheme.pretendard(size: 15, weight: .regular))
    .foregroundStyle(.white)
    .tint(AppTheme.gray30)
    .lineLimit(1...4)
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(AppTheme.blackTurquoise)
    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
  }

  private var sendButton: some View {
    Button(action: onSend) {
      ZStack {
        if isSending {
          ProgressView()
            .progressViewStyle(.circular)
            .tint(.white)
        } else {
          Image(systemName: "arrow.up.circle.fill")
            .font(.system(size: 30, weight: .regular))
            .foregroundStyle(canSend ? AppTheme.brightTurquoise : AppTheme.gray75)
        }
      }
      // tap target 44x44 (HIG 권장 최소값). 내부 Image 사이즈 30pt 그대로 유지.
      .frame(width: 44, height: 44)
    }
    .buttonStyle(.plain)
    .disabled(!canSend)
    .accessibilityLabel("메시지 전송")
  }
}
