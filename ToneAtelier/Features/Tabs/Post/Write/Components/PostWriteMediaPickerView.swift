//
//  PostWriteMediaPickerView.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//
//  Pencil node: rhnh0 (e_media)
//

import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Write 화면 미디어 영역. 좌측 메인 미리보기 + 우측 사진 추가 / 영상 추가 진입.
/// 1차 구현은 사진(이미지)만 지원하며, 영상은 진입 시 알림으로 차단(Tier 3에서 보강).
/// 첨부 한도 5개를 넘기지 않도록 PhotosPicker `maxSelectionCount`를 동적으로 줄인다.
struct PostWriteMediaPickerView: View {
  let attachments: [PostWriteFeature.AttachmentItem]
  let remainingSlots: Int
  let onPhotosLoaded: ([PostWriteFeature.PendingAttachment]) -> Void
  let onAttachmentRemove: (UUID) -> Void

  @State private var photoSelections: [PhotosPickerItem] = []
  @State private var isPhotosPickerPresented = false
  @State private var isLoadingMedia = false

  private var photosPickerSelectionLimit: Int {
    max(1, remainingSlots)
  }
  private var isAttachmentLimitReached: Bool {
    remainingSlots == 0
  }

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      mainPreview
        .frame(width: 214, height: 214)

      sideButtons
        .frame(width: 102)
    }
    .padding(8)
    .background(AppTheme.blackTurquoise)
    .overlay {
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(AppTheme.deepTurquoise, lineWidth: 1)
    }
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
      Task { await loadPhotos(from: snapshot) }
    }
  }

  // MARK: - Subviews

  @ViewBuilder
  private var mainPreview: some View {
    if let first = attachments.first {
      attachmentPreview(item: first, isMain: true)
    } else {
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(AppTheme.deepTurquoise)
        .overlay {
          VStack(spacing: 6) {
            Image(systemName: "photo.on.rectangle")
              .font(AppTheme.symbol(size: 28, weight: .regular))
              .foregroundStyle(AppTheme.gray60)
            Text("대표 사진을 추가해주세요")
              .font(AppTheme.pretendard(size: 11, weight: .bold))
              .foregroundStyle(AppTheme.gray60)
              .multilineTextAlignment(.center)
              .padding(.horizontal, 8)
          }
        }
    }
  }

  private var sideButtons: some View {
    VStack(spacing: 10) {
      addPhotoButton
      addVideoButton

      if attachments.count > 1 {
        thumbnailScroll
      }
    }
  }

  private var addPhotoButton: some View {
    Button {
      isPhotosPickerPresented = true
    } label: {
      VStack(spacing: 6) {
        if isLoadingMedia {
          ProgressView()
            .progressViewStyle(.circular)
            .tint(AppTheme.gray60)
        } else {
          Image(systemName: "photo.badge.plus")
            .font(AppTheme.symbol(size: 22, weight: .regular))
            .foregroundStyle(AppTheme.gray60)
        }
        Text("사진 추가")
          .font(AppTheme.pretendard(size: 11, weight: .bold))
          .foregroundStyle(AppTheme.gray60)
      }
      .frame(maxWidth: .infinity)
      .frame(height: 80)
      .background(AppTheme.deepTurquoise)
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .disabled(isAttachmentLimitReached || isLoadingMedia)
    .accessibilityLabel("사진 추가")
    .accessibilityIdentifier("post_write_add_photo_button")
  }

  private var addVideoButton: some View {
    Button {
      // TODO: Tier 3 — 영상 첨부 지원. 현재는 PHPicker가 video 모드일 때 데이터 변환 처리가 없어
      // 안내만 노출하지 않고 비활성 상태로 둔다.
    } label: {
      VStack(spacing: 6) {
        Image(systemName: "video.badge.plus")
          .font(AppTheme.symbol(size: 22, weight: .regular))
          .foregroundStyle(AppTheme.gray75)
        Text("영상 추가")
          .font(AppTheme.pretendard(size: 11, weight: .bold))
          .foregroundStyle(AppTheme.gray75)
      }
      .frame(maxWidth: .infinity)
      .frame(height: 80)
      .background(AppTheme.deepTurquoise.opacity(0.5))
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    .buttonStyle(.plain)
    .disabled(true)
    .accessibilityLabel("영상 추가 (준비 중)")
  }

  private var thumbnailScroll: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 6) {
        ForEach(Array(attachments.dropFirst()), id: \.id) { item in
          attachmentPreview(item: item, isMain: false)
            .frame(width: 44, height: 44)
        }
      }
    }
    .frame(height: 48)
  }

  @ViewBuilder
  private func attachmentPreview(item: PostWriteFeature.AttachmentItem, isMain: Bool) -> some View {
    ZStack(alignment: .topTrailing) {
      switch item {
      case let .pending(_, _, _, data):
        if let uiImage = UIImage(data: data) {
          Image(uiImage: uiImage)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: isMain ? 12 : 8, style: .continuous))
        } else {
          RoundedRectangle(cornerRadius: isMain ? 12 : 8, style: .continuous)
            .fill(AppTheme.deepTurquoise)
        }
      case let .uploaded(_, path):
        ChatImageView(
          path: path,
          baseURL: nil,
          shape: .roundedRect(cornerRadius: isMain ? 12 : 8)
        )
      }

      Button {
        onAttachmentRemove(item.id)
      } label: {
        Image(systemName: "xmark.circle.fill")
          .font(AppTheme.symbol(size: isMain ? 18 : 14, weight: .regular))
          .foregroundStyle(.white)
          .background(Circle().fill(AppTheme.background.opacity(0.6)))
          .padding(isMain ? 6 : 2)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("첨부 제거")
    }
  }

  // MARK: - Photo Loading

  /// PhotosPicker가 돌려준 PhotosPickerItem들을 Data로 변환해 PendingAttachment 배열로 콜백한다.
  /// SwiftUI 백그라운드 Task에서 진행해 메인 스레드를 막지 않으며, 실패 항목은 조용히 스킵한다.
  private func loadPhotos(from items: [PhotosPickerItem]) async {
    await MainActor.run { isLoadingMedia = true }
    defer { Task { @MainActor in isLoadingMedia = false } }

    var pending: [PostWriteFeature.PendingAttachment] = []
    for (offset, item) in items.enumerated() {
      do {
        if let data = try await item.loadTransferable(type: Data.self) {
          let mime: String
          let ext: String
          if let utType = item.supportedContentTypes.first {
            mime = utType.preferredMIMEType ?? "image/jpeg"
            ext = utType.preferredFilenameExtension ?? "jpg"
          } else {
            mime = "image/jpeg"
            ext = "jpg"
          }
          // 메모리 정책: ASCII 단순 파일명. 서버가 timestamp suffix 자동 부여.
          let fileName = "post_attachment_\(offset).\(ext)"
          pending.append(
            PostWriteFeature.PendingAttachment(
              fileName: fileName,
              mimeType: mime,
              data: data
            )
          )
        }
      } catch {
        // 단일 항목 실패는 전체 흐름을 막지 않는다.
        continue
      }
    }

    if !pending.isEmpty {
      let snapshot = pending
      await MainActor.run {
        onPhotosLoaded(snapshot)
      }
    }
  }
}
