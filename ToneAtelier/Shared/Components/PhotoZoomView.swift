//
//  PhotoZoomView.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//

import SwiftUI

/// 풀스크린 사진 zoom viewer.
///
/// 동작
/// - 여러 장 paging — `TabView(.page)` 좌우 스와이프로 이동.
/// - 핀치 zoom (`MagnifyGesture`) — 1.0x ~ 4.0x 범위로 clamp.
/// - 더블탭 zoom 토글 — 1.0x ↔ 2.5x.
/// - zoom > 1.0 일 때 드래그 패닝 활성, 페이지 이동은 비활성.
/// - 좌상단 닫기 버튼.
///
/// 페이지 전환 시 zoom/offset이 자동으로 초기화된다.
struct PhotoZoomView: View {
  let paths: [String]
  let initialIndex: Int
  let onClose: () -> Void

  @State private var currentIndex: Int

  init(paths: [String], initialIndex: Int = 0, onClose: @escaping () -> Void) {
    self.paths = paths
    self.initialIndex = max(0, min(initialIndex, max(paths.count - 1, 0)))
    self.onClose = onClose
    self._currentIndex = State(initialValue: max(0, min(initialIndex, max(paths.count - 1, 0))))
  }

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      pager

      closeButtonOverlay
        .zIndex(1)

      pageIndicator
        .zIndex(1)
    }
  }

  // MARK: - Pager

  private var pager: some View {
    TabView(selection: $currentIndex) {
      ForEach(Array(paths.enumerated()), id: \.offset) { index, path in
        PhotoZoomPage(path: path)
          .tag(index)
      }
    }
    .tabViewStyle(.page(indexDisplayMode: .never))
    .ignoresSafeArea()
  }

  // MARK: - Close button

  private var closeButtonOverlay: some View {
    VStack {
      HStack {
        Button(action: onClose) {
          Image(systemName: "xmark")
            .font(AppTheme.symbol(size: 18, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(Color.black.opacity(0.55))
            .clipShape(Circle())
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("닫기")
        .padding(.leading, 12)
        .padding(.top, 8)

        Spacer(minLength: 0)
      }

      Spacer(minLength: 0)
    }
  }

  @ViewBuilder
  private var pageIndicator: some View {
    if paths.count > 1 {
      VStack {
        Spacer(minLength: 0)
        Text("\(currentIndex + 1) / \(paths.count)")
          .pretendard(.captionBold)
          .foregroundStyle(.white)
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(Color.black.opacity(0.55))
          .clipShape(Capsule())
          .padding(.bottom, 24)
      }
    }
  }
}

/// 단일 사진 페이지. 자체 zoom/pan 상태를 보유해 페이지 전환 시 자동으로 1x로 리셋된다.
private struct PhotoZoomPage: View {
  let path: String

  @State private var scale: CGFloat = 1.0
  @State private var lastScale: CGFloat = 1.0
  @State private var offset: CGSize = .zero
  @State private var lastOffset: CGSize = .zero

  private static let minScale: CGFloat = 1.0
  private static let maxScale: CGFloat = 4.0
  private static let doubleTapZoom: CGFloat = 2.5

  var body: some View {
    GeometryReader { geo in
      ChatImageView(
        path: path,
        baseURL: nil,
        shape: .roundedRect(cornerRadius: 0),
        contentMode: .fit
      )
      .frame(width: geo.size.width, height: geo.size.height)
      .scaleEffect(scale)
      .offset(offset)
      .frame(width: geo.size.width, height: geo.size.height)
      .contentShape(.rect)
      .gesture(magnification)
      .simultaneousGesture(panning)
      .onTapGesture(count: 2) {
        handleDoubleTap()
      }
    }
    .clipped()
    .animation(.spring(response: 0.32, dampingFraction: 0.85), value: scale)
    .animation(.spring(response: 0.32, dampingFraction: 0.85), value: offset)
    .onDisappear {
      // 페이지 전환 시 zoom/pan 잔여값을 초기화한다.
      scale = Self.minScale
      lastScale = Self.minScale
      offset = .zero
      lastOffset = .zero
    }
  }

  private var magnification: some Gesture {
    MagnifyGesture()
      .onChanged { value in
        let proposed = lastScale * value.magnification
        scale = min(max(proposed, Self.minScale), Self.maxScale)
      }
      .onEnded { _ in
        lastScale = scale
        if scale <= Self.minScale {
          offset = .zero
          lastOffset = .zero
        }
      }
  }

  private var panning: some Gesture {
    DragGesture()
      .onChanged { value in
        guard scale > Self.minScale else { return }
        offset = CGSize(
          width: lastOffset.width + value.translation.width,
          height: lastOffset.height + value.translation.height
        )
      }
      .onEnded { _ in
        guard scale > Self.minScale else {
          offset = .zero
          lastOffset = .zero
          return
        }
        lastOffset = offset
      }
  }

  private func handleDoubleTap() {
    if scale > Self.minScale {
      scale = Self.minScale
      lastScale = Self.minScale
      offset = .zero
      lastOffset = .zero
    } else {
      scale = Self.doubleTapZoom
      lastScale = Self.doubleTapZoom
    }
  }
}
