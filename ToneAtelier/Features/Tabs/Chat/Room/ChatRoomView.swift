//
//  ChatRoomView.swift
//  ToneAtelier
//
//  Created by LCH on 4/29/26.
//

import ComposableArchitecture
import PhotosUI
import QuickLook
import SwiftUI
import UniformTypeIdentifiers

/// 카카오톡 스타일 채팅방 화면.
/// 부모(ChatTabFeature)가 NavigationStack에 push 한다.
/// 본 화면은 NavigationStack을 감싸지 않고 컨텐츠 + 입력바만 제공한다.
struct ChatRoomView: View {
  @Bindable var store: StoreOf<ChatRoomFeature>

  var body: some View {
    VStack(spacing: 0) {
      messagesArea
      ChatAttachmentPreviewView(
        attachments: store.attachments,
        isUploading: store.isSending,
        onRemove: { id in store.send(.attachmentRemoveTapped(id)) }
      )
      ChatInputBarView(
        text: $store.inputText,
        canSend: store.canSend,
        isSending: store.isSending,
        currentAttachmentCount: store.attachments.count,
        onSend: { store.send(.sendTapped) },
        onPhotosSelected: handlePhotos,
        onFilesImported: handleFiles
      )
    }
    .background(AppTheme.background.ignoresSafeArea())
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(AppTheme.background, for: .navigationBar)
    .toolbarColorScheme(.dark, for: .navigationBar)
    .toolbar {
      PrincipalToolbarTitle(store.displayOpponent?.nick ?? "채팅")
      PlainToolbarItem(placement: .topBarTrailing) {
        Menu {
          Button(role: .destructive) { store.send(.deleteRoomTapped) } label: {
            Label("채팅방 삭제", systemImage: "trash")
          }
        } label: {
          Image(systemName: "ellipsis")
            .resizable()
            .scaledToFit()
            .frame(width: 22, height: 22)
            .foregroundStyle(Color.white)
            .frame(width: 44, height: 44)
            .contentShape(.rect)
        }
        .accessibilityLabel("더보기")
      }
    }
    .alert($store.scope(state: \.alert, action: \.alert))
    .quickLookPreview(
      Binding(
        get: { store.previewingURL },
        set: { newValue in
          // QuickLook의 dismiss는 set(nil)로 통보된다. set(non-nil)은 reducer에서만 발생.
          if newValue == nil {
            store.send(.pdfPreviewDismissed)
          }
        }
      )
    )
    .task { await store.send(.task).finish() }
    .onDisappear { store.send(.onDisappear) }
  }

  // MARK: - Messages

  @ViewBuilder
  private var messagesArea: some View {
    ScrollViewReader { proxy in
      ScrollView(.vertical) {
        LazyVStack(spacing: 0) {
          ForEach(store.messages) { message in
            if showsDayDivider(for: message) {
              ChatDayDividerView(date: ChatDateUtilities.parseISO8601(message.createdAt))
            }
            ChatMessageBubbleView(
              message: message,
              isMine: isMine(message),
              showsHeader: showsHeader(for: message),
              showsTimestamp: showsTimestamp(for: message),
              baseURL: store.baseURL,
              onPDFTapped: { path in store.send(.pdfPreviewTapped(path: path)) },
              preparingPDFPath: store.preparingPreviewPath
            )
            .id(message.chatID)
          }
          // 가장 아래로 스크롤하기 위한 sentinel.
          Color.clear
            .frame(height: 1)
            .id(Self.bottomSentinelID)
        }
        .padding(.vertical, 8)
      }
      .scrollDismissesKeyboard(.interactively)
      .onAppear {
        scrollToBottom(proxy: proxy, animated: false)
      }
      .onChange(of: store.messages.last?.chatID) { _, _ in
        // 마지막 메시지 id 변경 시에만 스크롤. dedup으로 갱신될 때(동일 id) 불필요한 스크롤 회피.
        scrollToBottom(proxy: proxy, animated: true)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .overlay {
      if store.messages.isEmpty {
        if store.isLoadingHistory {
          loadingView
        } else {
          emptyView
        }
      }
    }
  }

  private var loadingView: some View {
    VStack(spacing: 12) {
      ProgressView()
        .progressViewStyle(.circular)
        .tint(AppTheme.gray45)
      Text("메시지를 불러오는 중...")
        .pretendard(.body2)
        .foregroundStyle(AppTheme.gray60)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var emptyView: some View {
    VStack(spacing: 12) {
      Image(systemName: "ellipsis.bubble")
        .font(AppTheme.symbol(size: 44, weight: .light))
        .foregroundStyle(AppTheme.gray60)
      Text("아직 주고받은 메시지가 없어요")
        .pretendard(.body1)
        .foregroundStyle(.white)
      Text("첫 메시지를 보내보세요")
        .pretendard(.body3)
        .foregroundStyle(AppTheme.gray60)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: - Helpers

  private static let bottomSentinelID = "ChatRoomView.bottomSentinel"

  private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
    if animated {
      withAnimation(.easeOut(duration: 0.2)) {
        proxy.scrollTo(Self.bottomSentinelID, anchor: .bottom)
      }
    } else {
      proxy.scrollTo(Self.bottomSentinelID, anchor: .bottom)
    }
  }

  private func isMine(_ message: ChatMessage) -> Bool {
    guard let currentUserID = store.currentUserID else { return false }
    return message.sender.userID == currentUserID
  }

  private func showsDayDivider(for message: ChatMessage) -> Bool {
    guard let index = store.messages.index(id: message.chatID) else { return false }
    guard index > 0 else { return true }
    let previous = store.messages[index - 1]
    let calendar = Calendar.current
    let currentDate = ChatDateUtilities.parseISO8601(message.createdAt)
    let previousDate = ChatDateUtilities.parseISO8601(previous.createdAt)
    return !calendar.isDate(currentDate, inSameDayAs: previousDate)
  }

  /// 같은 sender의 연속 메시지 그룹에서 첫 번째인지 (프로필/닉 표시).
  /// `IdentifiedArrayOf.index(id:)`는 O(1) 해시 조회이므로 호출당 비용은 상수.
  private func showsHeader(for message: ChatMessage) -> Bool {
    guard let index = store.messages.index(id: message.chatID) else { return true }
    guard index > 0 else { return true }
    let previous = store.messages[index - 1]
    return previous.sender.userID != message.sender.userID
  }

  /// 같은 sender 그룹에서 마지막 메시지이거나 분(min) 단위가 다음과 다르면 시간 표시.
  private func showsTimestamp(for message: ChatMessage) -> Bool {
    guard let index = store.messages.index(id: message.chatID) else { return true }
    let next = index + 1 < store.messages.count ? store.messages[index + 1] : nil
    guard let next else { return true }
    if next.sender.userID != message.sender.userID { return true }
    let currentDate = ChatDateUtilities.parseISO8601(message.createdAt)
    let nextDate = ChatDateUtilities.parseISO8601(next.createdAt)
    let calendar = Calendar.current
    let currentMinute = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: currentDate)
    let nextMinute = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: nextDate)
    return currentMinute != nextMinute
  }

  // MARK: - Attachment loading

  private func handlePhotos(_ items: [PhotosPickerItem]) {
    Task { @MainActor in
      var loaded: [LocalAttachment] = []
      for item in items {
        do {
          guard let data = try await item.loadTransferable(type: Data.self) else { continue }
          if data.count > ChatRoomFeature.maxAttachmentBytes {
            store.send(
              .attachmentLoadFailed(
                message: "5MB를 초과하는 파일은 첨부할 수 없어요."
              )
            )
            continue
          }
          let mime = mimeType(for: data) ?? "image/jpeg"
          let ext = fileExtension(forMime: mime)
          let attachmentID = UUID()
          let shortID = attachmentID.uuidString.prefix(8).lowercased()
          let safeFileName = "image-\(shortID).\(ext)"
          loaded.append(
            LocalAttachment(
              id: attachmentID,
              kind: .image,
              fileName: safeFileName,
              mimeType: mime,
              data: data,
              previewImage: data
            )
          )
        } catch {
          store.send(.attachmentLoadFailed(message: error.localizedDescription))
        }
      }
      if !loaded.isEmpty {
        store.send(.attachmentsAdded(loaded))
      }
    }
  }

  private func handleFiles(_ urls: [URL]) {
    var loaded: [LocalAttachment] = []
    for url in urls {
      let didStart = url.startAccessingSecurityScopedResource()
      defer {
        if didStart { url.stopAccessingSecurityScopedResource() }
      }
      do {
        let data = try Data(contentsOf: url)
        if data.count > ChatRoomFeature.maxAttachmentBytes {
          store.send(
            .attachmentLoadFailed(
              message: "5MB를 초과하는 파일은 첨부할 수 없어요."
            )
          )
          continue
        }
        let attachmentID = UUID()
        let shortID = attachmentID.uuidString.prefix(8).lowercased()
        let safeFileName = "attachment-\(shortID).pdf"
        loaded.append(
          LocalAttachment(
            id: attachmentID,
            kind: .pdf,
            fileName: safeFileName,
            mimeType: "application/pdf",
            data: data,
            previewImage: nil
          )
        )
      } catch {
        store.send(.attachmentLoadFailed(message: error.localizedDescription))
      }
    }
    if !loaded.isEmpty {
      store.send(.attachmentsAdded(loaded))
    }
  }

  /// magic-byte 기반 MIME 추정. PNG/JPEG/GIF 3종을 구분하고 나머지는 jpeg로 간주.
  private func mimeType(for data: Data) -> String? {
    let pngSig: [UInt8] = [0x89, 0x50, 0x4E, 0x47]
    if data.count >= 4 {
      let prefix = [UInt8](data.prefix(4))
      if prefix == pngSig { return "image/png" }
      if prefix.starts(with: [0xFF, 0xD8]) { return "image/jpeg" }
      if prefix == [0x47, 0x49, 0x46, 0x38] { return "image/gif" }
    }
    return nil
  }

  private func fileExtension(forMime mime: String) -> String {
    switch mime {
    case "image/png": return "png"
    case "image/gif": return "gif"
    default: return "jpg"
    }
  }
}

#Preview {
  NavigationStack {
    ChatRoomView(
      store: Store(
        initialState: ChatRoomFeature.State(
          roomID: "preview-room",
          opponent: ChatUserSummary(
            userID: "other",
            nick: "토니",
            name: nil,
            introduction: nil,
            profileImage: nil,
            hashTags: nil
          )
        )
      ) {
        ChatRoomFeature()
      }
    )
  }
  .preferredColorScheme(.dark)
}
