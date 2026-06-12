//
//  PostWriteMediaPickerView.swift
//  ToneAtelier
//

import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

// swiftlint:disable type_body_length file_length

struct PostWriteMediaPickerView: View {
  let attachments: [PostWriteFeature.AttachmentItem]
  let remainingSlots: Int
  let onPhotosLoaded: ([PostWriteFeature.PendingAttachment]) -> Void
  let onAttachmentReplaced: (Int, PostWriteFeature.PendingAttachment) -> Void
  let onAttachmentMoved: (Int, Int) -> Void
  let onAttachmentRemove: (UUID) -> Void
  let onCameraTapped: () -> Void

  @State private var photoSelections: [PhotosPickerItem] = []
  @State private var isPhotosPickerPresented = false
  @State private var isLoadingMedia = false
  @State private var selectedIndex: Int = 0
  @State private var replacingIndex: Int?
  @State private var localAttachments: [PostWriteFeature.AttachmentItem] = []
  @State private var draggedItem: PostWriteFeature.AttachmentItem?
  @State private var dragOriginIndex: Int?

  private var photosPickerSelectionLimit: Int {
    if replacingIndex != nil { return 1 }
    return max(1, remainingSlots)
  }
  private var isAttachmentLimitReached: Bool { remainingSlots == 0 }
  private var visibleAttachments: [PostWriteFeature.AttachmentItem] {
    draggedItem == nil ? attachments : localAttachments
  }

  var body: some View {
    VStack(spacing: 0) {
      mainPreview
        .frame(maxWidth: .infinity)
        .frame(height: 214)
        .clipped()

      thumbStrip
        .frame(height: 58)
        .frame(maxWidth: .infinity)
        .background(AppTheme.blackTurquoise)
        .overlay(alignment: .top) {
          Rectangle()
            .fill(AppTheme.deepTurquoise)
            .frame(height: 1)
        }
    }
    .background(AppTheme.blackTurquoise)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .photosPicker(
      isPresented: $isPhotosPickerPresented,
      selection: $photoSelections,
      maxSelectionCount: photosPickerSelectionLimit,
      matching: .any(of: [.images, .videos]),
      photoLibrary: .shared()
    )
    .onAppear {
      if localAttachments.isEmpty {
        localAttachments = attachments
      }
    }
    .onChange(of: attachments) { _, new in
      guard draggedItem == nil else { return }
      localAttachments = new
    }
    .onChange(of: photoSelections) { _, newValue in
      guard !newValue.isEmpty else { return }
      let snapshot = newValue
      photoSelections = []
      Task { await loadPhotos(from: snapshot) }
    }
    .onChange(of: attachments.count) { _, newCount in
      if selectedIndex >= newCount {
        selectedIndex = max(0, newCount - 1)
      }
    }
  }

  @ViewBuilder
  private var mainPreview: some View {
    let source = visibleAttachments
    if source.isEmpty {
      emptyMain
    } else {
      let safeIndex = min(selectedIndex, source.count - 1)
      let item = source[safeIndex]
      mainPreviewBody(for: item)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .overlay(alignment: .topLeading) {
          filterButton.padding(12)
        }
        .overlay(alignment: .topTrailing) {
          deleteButton(itemID: item.id).padding(12)
        }
    }
  }

  private var emptyMain: some View {
    HStack(spacing: 12) {
      emptyCtaButton(
        title: "앨범에서 선택",
        subtitle: "사진을 가져와 첨부",
        systemImage: "photo.stack",
        accentStroke: false
      ) {
        replacingIndex = nil
        isPhotosPickerPresented = true
      }

      emptyCtaButton(
        title: "직접 촬영",
        subtitle: "필터 적용된 카메라",
        systemImage: "camera",
        accentStroke: true
      ) {
        onCameraTapped()
      }
    }
    .padding(.horizontal, 20)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(AppTheme.deepTurquoise)
    .accessibilityIdentifier("post_write_add_photo_button")
  }

  private func emptyCtaButton(
    title: String,
    subtitle: String,
    systemImage: String,
    accentStroke: Bool,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      VStack(spacing: 8) {
        if isLoadingMedia {
          ProgressView().tint(AppTheme.gray60)
        } else {
          Image(systemName: systemImage)
            .font(AppTheme.symbol(size: 22, weight: .regular))
            .foregroundStyle(accentStroke ? AppTheme.brightTurquoise : AppTheme.gray30)
        }
        Text(title)
          .pretendard(.captionBold)
          .foregroundStyle(AppTheme.gray30)
        Text(subtitle)
          .pretendard(.caption2)
          .foregroundStyle(AppTheme.gray60)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(AppTheme.blackTurquoise)
      .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(
            accentStroke ? AppTheme.brightTurquoise : AppTheme.deepTurquoise,
            lineWidth: accentStroke ? 1.5 : 1
          )
      )
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .disabled(isLoadingMedia)
  }

  @ViewBuilder
  private func mainPreviewBody(for item: PostWriteFeature.AttachmentItem) -> some View {
    if case let .pending(id, _, mimeType, data) = item, mimeType.hasPrefix("video/") {
      LocalVideoMediaView(id: id, data: data, mimeType: mimeType)
    } else {
      attachmentImage(item)
    }
  }

  @ViewBuilder
  private func attachmentImage(_ item: PostWriteFeature.AttachmentItem) -> some View {
    switch item {
    case let .pending(id, _, mimeType, data):
      if mimeType.hasPrefix("video/") {
        LocalVideoThumbnailView(id: id, data: data, mimeType: mimeType)
      } else if let uiImage = UIImage(data: data) {
        Image(uiImage: uiImage)
          .resizable()
          .scaledToFill()
      } else {
        AppTheme.deepTurquoise
      }
    case let .uploaded(_, path):
      ChatImageView(path: path, baseURL: nil, shape: .roundedRect(cornerRadius: 0))
    }
  }

  private var filterButton: some View {
    HStack(spacing: 4) {
      Image(systemName: "wand.and.stars")
        .font(AppTheme.symbol(size: 12, weight: .regular))
      Text("필터")
        .pretendard(.captionMeta)
    }
    .foregroundStyle(AppTheme.gray30)
    .padding(.horizontal, 12)
    .frame(height: 28)
    .background(AppTheme.background.opacity(0.8))
    .clipShape(Capsule())
  }

  private func deleteButton(itemID: UUID) -> some View {
    Button {
      onAttachmentRemove(itemID)
    } label: {
      Image(systemName: "trash")
        .font(AppTheme.symbol(size: 16, weight: .regular))
        .foregroundStyle(AppTheme.gray30)
        .frame(width: 32, height: 32)
        .background(AppTheme.background.opacity(0.6))
        .clipShape(Circle())
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("선택 미디어 삭제")
  }

  private var thumbStrip: some View {
    HStack(spacing: 8) {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 6) {
          ForEach(Array(visibleAttachments.enumerated()), id: \.element.id) { index, item in
            thumbCell(at: index, item: item)
          }

          if !isAttachmentLimitReached {
            addThumbButton
            cameraThumbButton
          }
        }
        .padding(.horizontal, 12)
        .animation(.easeInOut(duration: 0.18), value: localAttachments.map(\.id))
      }
      .onDrop(
        of: [.text],
        delegate: OuterCancelDropDelegate(
          attachments: $localAttachments,
          draggedItem: $draggedItem,
          dragOriginIndex: $dragOriginIndex,
          externalAttachments: attachments
        )
      )

      Spacer(minLength: 0)

      VStack(alignment: .trailing, spacing: 2) {
        Text("길게 눌러 순서 변경")
          .pretendard(.caption2Bold)
          .foregroundStyle(AppTheme.gray75)
        Text("선택 항목 교체")
          .pretendard(.caption2Bold)
          .foregroundStyle(AppTheme.gray60)
      }
      .padding(.trailing, 12)
    }
  }

  private func thumbCell(at index: Int, item: PostWriteFeature.AttachmentItem) -> some View {
    let isSelected = index == selectedIndex
    return Button {
      if isSelected {
        replacingIndex = index
        isPhotosPickerPresented = true
      } else {
        selectedIndex = index
      }
    } label: {
      ZStack(alignment: .topLeading) {
        attachmentImage(item)
          .frame(width: 48, height: 42)
          .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
          .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
              .stroke(
                isSelected ? AppTheme.brightTurquoise : AppTheme.deepTurquoise,
                lineWidth: isSelected ? 2 : 1
              )
          }

        Text("\(index + 1)")
          .pretendard(.caption2Bold)
          .foregroundStyle(AppTheme.gray30)
          .padding(.horizontal, 4)
          .padding(.vertical, 1)
          .background(AppTheme.background.opacity(0.7))
          .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
          .padding(2)
      }
    }
    .buttonStyle(.plain)
    .onDrag {
      guard draggedItem == nil else { return NSItemProvider() }
      dragOriginIndex = localAttachments.firstIndex(where: { $0.id == item.id })
      draggedItem = item
      return NSItemProvider(object: item.id.uuidString as NSString)
    } preview: {
      attachmentImage(item)
        .frame(width: 48, height: 42)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    .onDrop(
      of: [.text],
      delegate: ReorderDropDelegate(
        targetItem: item,
        attachments: $localAttachments,
        draggedItem: $draggedItem,
        dragOriginIndex: $dragOriginIndex,
        externalAttachments: attachments,
        onCommit: { from, to in
          onAttachmentMoved(from, to)
        }
      )
    )
  }

  private var addThumbButton: some View {
    Button {
      replacingIndex = nil
      isPhotosPickerPresented = true
    } label: {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(AppTheme.deepTurquoise)
        .overlay {
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(AppTheme.brightTurquoise, lineWidth: 1)
        }
        .frame(width: 48, height: 42)
        .overlay {
          Image(systemName: "plus")
            .font(AppTheme.symbol(size: 16, weight: .regular))
            .foregroundStyle(AppTheme.gray30)
        }
    }
    .buttonStyle(.plain)
    .disabled(isLoadingMedia)
    .accessibilityLabel("사진 추가")
  }

  private var cameraThumbButton: some View {
    Button(action: onCameraTapped) {
      HStack(spacing: 4) {
        Image(systemName: "camera")
          .font(AppTheme.symbol(size: 14, weight: .regular))
          .foregroundStyle(AppTheme.brightTurquoise)
        Text("촬영")
          .pretendard(.caption2Bold)
          .foregroundStyle(AppTheme.gray30)
      }
      .padding(.horizontal, 10)
      .frame(height: 42)
      .background(AppTheme.blackTurquoise)
      .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .stroke(AppTheme.brightTurquoise, lineWidth: 1.2)
      )
    }
    .buttonStyle(.plain)
    .disabled(isLoadingMedia)
    .accessibilityLabel("카메라로 촬영")
  }

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
        continue
      }
    }

    guard !pending.isEmpty else { return }
    let snapshot = pending
    await MainActor.run {
      if let replacing = replacingIndex, let first = snapshot.first {
        onAttachmentReplaced(replacing, first)
      } else {
        onPhotosLoaded(snapshot)
      }
      replacingIndex = nil
    }
  }
}

private struct ReorderDropDelegate: DropDelegate {
  let targetItem: PostWriteFeature.AttachmentItem
  @Binding var attachments: [PostWriteFeature.AttachmentItem]
  @Binding var draggedItem: PostWriteFeature.AttachmentItem?
  @Binding var dragOriginIndex: Int?
  let externalAttachments: [PostWriteFeature.AttachmentItem]
  let onCommit: (Int, Int) -> Void

  func dropEntered(info: DropInfo) {
    guard let dragged = draggedItem, dragged.id != targetItem.id else { return }
    guard
      let from = attachments.firstIndex(where: { $0.id == dragged.id }),
      let to = attachments.firstIndex(where: { $0.id == targetItem.id })
    else { return }
    if from != to {
      withAnimation(.easeInOut(duration: 0.18)) {
        attachments.move(
          fromOffsets: IndexSet(integer: from),
          toOffset: to > from ? to + 1 : to
        )
      }
    }
  }

  func performDrop(info: DropInfo) -> Bool {
    defer {
      draggedItem = nil
      dragOriginIndex = nil
    }
    guard
      let dragged = draggedItem,
      let origin = dragOriginIndex,
      let final = attachments.firstIndex(where: { $0.id == dragged.id })
    else { return false }
    if origin != final {
      onCommit(origin, final)
    }
    return true
  }

  func dropUpdated(info: DropInfo) -> DropProposal? {
    DropProposal(operation: .move)
  }
}

private struct OuterCancelDropDelegate: DropDelegate {
  @Binding var attachments: [PostWriteFeature.AttachmentItem]
  @Binding var draggedItem: PostWriteFeature.AttachmentItem?
  @Binding var dragOriginIndex: Int?
  let externalAttachments: [PostWriteFeature.AttachmentItem]

  func performDrop(info: DropInfo) -> Bool {
    withAnimation(.easeInOut(duration: 0.18)) {
      attachments = externalAttachments
    }
    draggedItem = nil
    dragOriginIndex = nil
    return false
  }

  func dropUpdated(info: DropInfo) -> DropProposal? {
    DropProposal(operation: .move)
  }
}
