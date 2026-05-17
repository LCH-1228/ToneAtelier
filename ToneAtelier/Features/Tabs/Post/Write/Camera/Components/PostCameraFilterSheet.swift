//
//  PostCameraFilterSheet.swift
//  ToneAtelier
//
//  Pencil: VlQiR 의 sheet(oeeVY) — 헤더 + 탭(전체/내 필터/구입한 필터) + 강도 슬라이더 + 4열 그리드.
//  cell 미리보기는 라이브 카메라 프레임을 base 로 각 필터의 MakeFilterValues 를 적용한다.
//

import ComposableArchitecture
import CoreImage
import SwiftUI

struct PostCameraFilterSheet: View {
  @Bindable var store: StoreOf<PostCameraFeature>
  @ObservedObject var frameRelay: PostCameraFrameRelay

  var body: some View {
    VStack(spacing: 0) {
      header
      tabsRow
      if shouldShowIntensity {
        intensityCard
      }
      filterGrid
    }
    .padding(.bottom, 24)
    .frame(maxWidth: .infinity)
  }

  private var shouldShowIntensity: Bool {
    guard let selected = store.selectedFilter else { return false }
    return selected.isOwned
  }

  private var header: some View {
    HStack(spacing: 0) {
      Text("필터")
        .pretendard(.body3Bold)
        .foregroundStyle(AppTheme.gray30)
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 18)
    .padding(.top, 8)
    .padding(.bottom, 12)
  }

  private var tabsRow: some View {
    HStack(spacing: 6) {
      tabButton(.all, count: store.allTabCount)
      tabButton(.created, count: store.createdTabCount)
      tabButton(.purchased, count: store.purchasedTabCount)
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 18)
    .padding(.bottom, 14)
  }

  private func tabButton(_ tab: PostCameraSheetTab, count: Int) -> some View {
    let isActive = store.sheetTab == tab
    return Button(
      action: { store.send(.sheetTabTapped(tab)) },
      label: {
        HStack(spacing: 6) {
          Text(tab.displayLabel)
            .pretendard(.captionBold)
            .foregroundStyle(isActive ? AppTheme.background : AppTheme.gray30)
          Text("\(count)")
            .pretendard(.caption2Bold)
            .foregroundStyle(isActive ? AppTheme.background.opacity(0.7) : AppTheme.gray30.opacity(0.7))
            .padding(.horizontal, 6)
            .frame(height: 14)
            .background(
              isActive
                ? AppTheme.background.opacity(0.18)
                : AppTheme.gray30.opacity(0.1)
            )
            .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
        .frame(height: 32)
        .background(isActive ? AnyShapeStyle(AppTheme.brightTurquoise) : AnyShapeStyle(AppTheme.gray30.opacity(0.08)))
        .clipShape(Capsule())
      }
    )
    .buttonStyle(.plain)
    .accessibilityLabel("\(tab.displayLabel) (\(count))")
  }

  @ViewBuilder
  private var intensityCard: some View {
    if let selected = store.selectedFilter {
      PostCameraIntensitySlider(
        filterTitle: selected.title,
        intensity: store.filterIntensity,
        onChange: { store.send(.intensityChanged($0)) }
      )
      .padding(.horizontal, 18)
      .padding(.bottom, 14)
    }
  }

  private var filterGrid: some View {
    let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 4)
    return ScrollView {
      LazyVGrid(columns: columns, spacing: 14) {
        PostCameraFilterCell(
          filter: PostCameraFilterSheet.originalFilter,
          isSelected: store.selectedFilter == nil,
          baseFrame: frameRelay.latestFrame,
          frameTick: frameRelay.frameTick,
          needsDetailLoad: false,
          onTap: { store.send(.filterChipTapped(nil)) },
          onLoadDetail: {}
        )
        ForEach(store.sheetVisibleFilters) { filter in
          let cached = store.filterDetailsCache[filter.id]
          let raw = cached ?? filter.filterValues
          let isSelected = store.selectedFilter?.id == filter.id
          // 선택된 필터 cell 만 강도 슬라이더 영향 — 다른 cell 은 100% 미리보기로 비교용.
          let displayedValues = isSelected
            ? raw.intensityScaled(store.filterIntensity)
            : raw
          let resolved = filter.with(filterValues: displayedValues)
          let needsDetail = filter.filterValues == .default && cached == nil
          PostCameraFilterCell(
            filter: resolved,
            isSelected: isSelected,
            baseFrame: frameRelay.latestFrame,
            frameTick: frameRelay.frameTick,
            needsDetailLoad: needsDetail,
            onTap: { store.send(.filterChipTapped(filter.with(filterValues: raw))) },
            onLoadDetail: { store.send(.loadFilterDetail(filterID: filter.id)) }
          )
        }
      }
      .padding(.horizontal, 14)
      .padding(.bottom, 8)
    }
    .frame(maxHeight: 240)
  }

  private static let originalFilter = PostCameraFilter(
    id: "__original__",
    title: "원본",
    previewImagePath: nil,
    filterValues: .default,
    isOwned: true,
    price: nil,
    swatchColor: AppTheme.gray30.opacity(0.2)
  )
}

private struct CellRenderKey: Equatable {
  let values: MakeFilterValues
  let tick: Int
}

private struct PostCameraFilterCell: View {
  /// 단일 source of truth — swatch 의 표시/렌더 사이즈가 모두 이 값에서 파생.
  /// 디자인이 바뀌면 이 한 줄만 수정.
  static let cellSize: CGFloat = 64

  let filter: PostCameraFilter
  let isSelected: Bool
  let baseFrame: CIImage?
  let frameTick: Int
  let needsDetailLoad: Bool
  let onTap: () -> Void
  let onLoadDetail: () -> Void

  @Environment(\.displayScale) private var displayScale
  @State private var renderedThumbnail: UIImage?

  var body: some View {
    VStack(spacing: 6) {
      Button(action: onTap, label: { swatch })
        .buttonStyle(.plain)
        .task(id: CellRenderKey(values: filter.filterValues, tick: frameTick)) {
          // 첫 진입 시 detail() 미수신이면 prefetch.
          if needsDetailLoad {
            onLoadDetail()
          }
          let pixelSize = Self.cellSize * displayScale
          let rendered = await PostCameraSwatchRenderer.shared.render(
            filter: filter,
            baseImage: baseFrame,
            pixelSize: pixelSize
          )
          await MainActor.run { renderedThumbnail = rendered }
        }

      Text(filter.title)
        .pretendard(.caption2Bold)
        .foregroundStyle(isSelected ? AppTheme.brightTurquoise : AppTheme.gray30)
        .lineLimit(1)
    }
  }

  private var swatch: some View {
    ZStack {
      if let renderedThumbnail {
        Image(uiImage: renderedThumbnail)
          .resizable()
          .scaledToFill()
          .frame(width: Self.cellSize, height: Self.cellSize)
      } else if let path = filter.previewImagePath {
        ChatImageView(path: path, baseURL: nil, shape: .roundedRect(cornerRadius: 12))
          .frame(width: Self.cellSize, height: Self.cellSize)
      } else {
        Rectangle()
          .fill(filter.swatchColor)
          .frame(width: Self.cellSize, height: Self.cellSize)
      }

      if !filter.isOwned {
        Rectangle()
          .fill(AppTheme.background.opacity(0.55))
          .frame(width: Self.cellSize, height: Self.cellSize)
        Image(systemName: "lock.fill")
          .font(AppTheme.symbol(size: 14, weight: .regular))
          .foregroundStyle(AppTheme.gray30)
      }
    }
    .frame(width: 64, height: 64)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .stroke(
          isSelected ? AppTheme.brightTurquoise : AppTheme.gray30.opacity(0.15),
          lineWidth: isSelected ? 2 : 1
        )
    )
  }
}
