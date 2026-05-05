//
//  VideoDetailView.swift
//  ToneAtelier
//
//  Created by Codex on 5/5/26.
//

import ComposableArchitecture
import SwiftUI

struct VideoDetailView: View {
  @Bindable var store: StoreOf<VideoDetailFeature>
  @State private var dragOffset: CGSize = .zero
  // playerHolder 는 view 외부 @State — 풀스크린 토글로 view 가 재마운트돼도 currentTime 보존.
  @State private var playerHolder = VideoPlayerHolder()

  private static let dismissThreshold: CGFloat = 120

  var body: some View {
    // stage 가 view tree 의 같은 position 을 유지해야 player 가 재마운트되지 않는다.
    ZStack {
      backgroundLayer
      VStack(spacing: 0) {
        if !store.isFullscreen {
          headerBar
        }
        stage
          .modifier(StagePresentation(isFullscreen: store.isFullscreen, dragOffset: dragOffset))
          .gesture(store.isFullscreen ? dismissDragGesture : nil)
        if !store.isFullscreen {
          ScrollView {
            VStack(alignment: .leading, spacing: 16) {
              infoPanel
              recommendedSection
            }
            .padding(.top, 16)
            .padding(.bottom, 32)
          }
          .scrollIndicators(.hidden)
        }
      }
    }
    .toolbar(.hidden, for: .navigationBar)
    .statusBarHidden(store.isFullscreen)
    .animation(.spring(response: 0.42, dampingFraction: 0.85), value: store.isFullscreen)
    // 추천 swap 시 view 재마운트 → playerHolder 새 인스턴스. 풀스크린 토글에는 영향 없음.
    .id(store.video.videoID)
    .task { store.send(.task) }
    .onChange(of: store.isFullscreen) { _, newValue in
      applyFullscreenOrientation(newValue)
      withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
        dragOffset = .zero
      }
    }
    .onDisappear {
      // 풀스크린 상태로 detail 이 사라지면 다른 화면이 가로로 뜰 수 있어 회전 lock 복구.
      if store.isFullscreen {
        AppDelegate.supportedOrientations = .portrait
      }
      playerHolder.teardown()
    }
  }

  private var backgroundLayer: some View {
    (store.isFullscreen ? Color.black : AppTheme.background)
      .ignoresSafeArea()
  }

  // mask 를 미리 풀어둬야 시스템 자동 회전이 trigger 됨 (completion 안에서 풀면 늦음).
  private func applyFullscreenOrientation(_ newValue: Bool) {
    let scene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first
    let rootVC = scene?.keyWindow?.rootViewController
    if newValue {
      AppDelegate.supportedOrientations = .allButUpsideDown
      rootVC?.setNeedsUpdateOfSupportedInterfaceOrientations()
      scene?.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
    } else {
      AppDelegate.supportedOrientations = .portrait
      rootVC?.setNeedsUpdateOfSupportedInterfaceOrientations()
      scene?.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
    }
  }

  private struct StagePresentation: ViewModifier {
    let isFullscreen: Bool
    let dragOffset: CGSize
    func body(content: Content) -> some View {
      if isFullscreen {
        content
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .offset(y: max(0, dragOffset.height))
      } else {
        content
          .aspectRatio(16.0 / 10.0, contentMode: .fit)
          .frame(maxWidth: .infinity)
      }
    }
  }

  // 가로 우세 drag 는 ScrubBar 가 가져가도록 무시.
  private var dismissDragGesture: some Gesture {
    DragGesture(minimumDistance: 10)
      .onChanged { value in
        let h = value.translation.height
        let w = value.translation.width
        guard h > 0, abs(h) > abs(w) else { return }
        dragOffset = CGSize(width: 0, height: h)
      }
      .onEnded { value in
        if value.translation.height > Self.dismissThreshold,
           abs(value.translation.height) > abs(value.translation.width) {
          store.send(.fullscreenToggled)
        } else {
          withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            dragOffset = .zero
          }
        }
      }
  }

  // MARK: - Header

  private var headerBar: some View {
    HStack(spacing: 0) {
      Button {
        store.send(.backTapped)
      } label: {
        Image(systemName: "chevron.left")
          .font(AppTheme.symbol(size: 22, weight: .regular))
          .foregroundStyle(AppTheme.gray60)
          .frame(width: 44, height: 44)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("video_detail_back")

      Spacer(minLength: 0)
      Text("VIDEO")
        .mulgyeol(.pageTitle)
        .foregroundStyle(AppTheme.gray60)
      Spacer(minLength: 0)

      Color.clear.frame(width: 44, height: 44)
    }
    .frame(height: 56)
    .padding(.horizontal, 12)
  }

  // MARK: - Stage

  private var stage: some View {
    Group {
      if let url = activeStreamURL {
        HLSVideoPlayerView(
          streamURL: url,
          cues: store.subtitleCues,
          posterPath: store.video.thumbnailURL,
          preferredPeakBitRate: bitRateCap(for: store.selectedQuality),
          qualities: store.streamResponse?.qualities ?? [],
          selectedQuality: store.selectedQuality,
          subtitles: store.streamResponse?.subtitles ?? [],
          selectedSubtitle: store.selectedSubtitle,
          onQualitySelect: { store.send(.qualitySelected($0)) },
          onSubtitleSelect: { store.send(.subtitleSelected($0)) },
          onTimeUpdate: { current, duration in
            store.send(.timeUpdated(current: current, duration: duration))
          },
          isFullscreen: store.isFullscreen,
          onFullscreenToggle: { store.send(.fullscreenToggled) },
          holder: playerHolder
        )
        .modifier(StageAspectModifier(isFullscreen: store.isFullscreen))
      } else {
        ZStack {
          Color.black
          if store.isStreamLoading {
            ProgressView()
              .progressViewStyle(.circular)
              .tint(AppTheme.gray45)
          } else if let message = store.errorMessage {
            Text(message)
              .pretendard(.body3)
              .foregroundStyle(AppTheme.gray60)
              .multilineTextAlignment(.center)
              .padding(.horizontal, 24)
          }
        }
        .modifier(StageAspectModifier(isFullscreen: store.isFullscreen))
      }
    }
  }

  private struct StageAspectModifier: ViewModifier {
    let isFullscreen: Bool
    func body(content: Content) -> some View {
      if isFullscreen {
        content
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        content
          .aspectRatio(16.0 / 10.0, contentMode: .fit)
          .frame(maxWidth: .infinity)
      }
    }
  }

  // MARK: - Info panel

  private var infoPanel: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(store.video.title)
        .pretendard(.body1)
        .foregroundStyle(AppTheme.gray30)

      HStack(alignment: .center, spacing: 12) {
        VideoOfficialAvatar(size: 40)
        Text(VideoMetaFormatter.detailChannelMeta(for: store.video))
          .pretendard(.caption2Bold)
          .foregroundStyle(Color(hex: 0x8F8F94))
          .frame(maxWidth: .infinity, alignment: .leading)
        likeButton
      }

      if !store.video.description.isEmpty {
        Text(store.video.description)
          .pretendard(.caption2Bold)
          .foregroundStyle(Color(hex: 0xB9CBD1))
          .multilineTextAlignment(.leading)
          .padding(.vertical, 10)
          .padding(.horizontal, 12)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(Color(hex: 0x293235).opacity(0.53), in: RoundedRectangle(cornerRadius: 10))
      }
    }
    .padding(.horizontal, 16)
    .padding(.top, 16)
    .padding(.bottom, 14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(AppTheme.blackTurquoise)
    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .strokeBorder(AppTheme.deepTurquoise, lineWidth: 1)
    )
    .padding(.horizontal, 20)
  }

  private var likeButton: some View {
    Button {
      store.send(.likeToggled)
    } label: {
      HStack(spacing: 4) {
        Text("\(store.video.likeCount)")
          .pretendard(.caption2Bold)
          .foregroundStyle(AppTheme.gray30)
        Image(systemName: store.video.isLiked ? "heart.fill" : "heart")
          .font(AppTheme.symbol(size: 18, weight: .regular))
          .foregroundStyle(store.video.isLiked ? Color(hex: 0xFF6B7A) : AppTheme.gray60)
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("video_detail_like")
  }

  // MARK: - Recommended

  @ViewBuilder
  private var recommendedSection: some View {
    if let next = store.recommendedVideo {
      VStack(alignment: .leading, spacing: 12) {
        Text("다음 추천영상")
          .pretendard(.body1)
          .foregroundStyle(AppTheme.gray30)
          .padding(.horizontal, 20)
          .padding(.top, 8)

        VideoListCard(
          video: next,
          watchProgress: 0.5,
          onTap: { store.send(.recommendedTapped) },
          onLikeTap: {}
        )
        .padding(.horizontal, 20)
      }
    }
  }

  // MARK: - Helpers

  private var activeStreamURL: URL? {
    if let stream = store.absoluteStreamURL {
      return stream
    }
    if let selected = store.selectedQuality,
       let url = store.absoluteQualityURLs[selected] {
      return url
    }
    return store.absoluteQualityURLs.first?.value
  }

  private func bitRateCap(for selected: String?) -> Double {
    guard let selected else { return 0 }
    let digits = selected.filter(\.isNumber)
    switch Int(digits) {
    case 1080: return 5_000_000
    case 720: return 2_500_000
    case 480: return 1_000_000
    case 360: return 700_000
    default: return 0
    }
  }
}

#Preview {
  NavigationStack {
    VideoDetailView(
      store: Store(
        initialState: VideoDetailFeature.State(
          video: VideoResponseDTO(
            videoID: "preview",
            fileName: "preview",
            title: "프로처럼 보정하는 아이폰 보정법 심화편",
            description: "한 단계 더 깊이 있는 보정을 원하는 분들을 위한 심화 가이드입니다.",
            duration: 711,
            thumbnailURL: "/data/videos/filter_video_5.jpg",
            availableQualities: ["1080p", "720p", "480p"],
            viewCount: 165,
            likeCount: 1,
            isLiked: true,
            createdAt: "2026-01-03T11:51:04.939Z"
          )
        )
      ) {
        VideoDetailFeature()
      }
    )
  }
  .preferredColorScheme(.dark)
}
