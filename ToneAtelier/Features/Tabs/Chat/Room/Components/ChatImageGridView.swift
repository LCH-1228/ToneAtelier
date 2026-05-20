//
//  ChatImageGridView.swift
//  ToneAtelier
//
//  Created by LCH on 4/29/26.
//

import SwiftUI

/// 카카오톡 스타일 첨부 이미지 그리드.
///
/// 한 메시지에 사진이 1~5장 포함될 때 카톡과 동일한 패턴으로 배치한다.
/// - 1장: 큰 단일 박스 (`maxSide` × `maxSide`).
/// - 2장: 가로 분할.
/// - 3장: 위쪽 큰 1장 + 아래쪽 가로 2장.
/// - 4장: 2x2.
/// - 5장: 위 큰 1장 + 아래 가로 4장.
///
/// 5장 초과는 명세상 발생하지 않으므로 fallback 케이스에서 첫 1장만 노출한다.
struct ChatImageGridView: View {
  let paths: [String]
  let baseURL: URL?

  var body: some View {
    switch paths.count {
    case 1: singleLayout
    case 2: pairLayout
    case 3: trioLayout
    case 4: quadLayout
    case 5: quintLayout
    default: fallbackLayout
    }
  }

  // MARK: - Layouts

  /// 1장: 큰 단일 박스(220x220 이내). 비율은 scaledToFill로 채움.
  private var singleLayout: some View {
    ChatImageView(
      path: paths[0],
      baseURL: baseURL,
      shape: .roundedRect(cornerRadius: ImageGridLayout.singleCornerRadius)
    )
    .frame(width: ImageGridLayout.maxSide, height: ImageGridLayout.maxSide)
  }

  /// 2장: 가로 분할.
  private var pairLayout: some View {
    HStack(spacing: ImageGridLayout.spacing) {
      gridCell(path: paths[0])
      gridCell(path: paths[1])
    }
    .frame(
      width: ImageGridLayout.maxSide,
      height: ImageGridLayout.halfSide
    )
    .clipShape(
      RoundedRectangle(
        cornerRadius: ImageGridLayout.gridCornerRadius,
        style: .continuous
      )
    )
  }

  /// 3장: 2x2에서 마지막 한 칸이 비는 형태로는 어색하므로
  /// "위쪽 큰 1장 + 아래쪽 2장" 카톡 패턴으로 표현.
  private var trioLayout: some View {
    VStack(spacing: ImageGridLayout.spacing) {
      gridCell(path: paths[0])
        .frame(height: ImageGridLayout.halfSide)
      HStack(spacing: ImageGridLayout.spacing) {
        gridCell(path: paths[1])
        gridCell(path: paths[2])
      }
      .frame(height: ImageGridLayout.halfSide)
    }
    .frame(width: ImageGridLayout.maxSide)
    .clipShape(
      RoundedRectangle(
        cornerRadius: ImageGridLayout.gridCornerRadius,
        style: .continuous
      )
    )
  }

  /// 4장: 2x2.
  private var quadLayout: some View {
    VStack(spacing: ImageGridLayout.spacing) {
      HStack(spacing: ImageGridLayout.spacing) {
        gridCell(path: paths[0])
        gridCell(path: paths[1])
      }
      .frame(height: ImageGridLayout.halfSide)
      HStack(spacing: ImageGridLayout.spacing) {
        gridCell(path: paths[2])
        gridCell(path: paths[3])
      }
      .frame(height: ImageGridLayout.halfSide)
    }
    .frame(width: ImageGridLayout.maxSide)
    .clipShape(
      RoundedRectangle(
        cornerRadius: ImageGridLayout.gridCornerRadius,
        style: .continuous
      )
    )
  }

  /// 5장: 위 큰 1장 + 아래 2x2.
  private var quintLayout: some View {
    VStack(spacing: ImageGridLayout.spacing) {
      gridCell(path: paths[0])
        .frame(height: ImageGridLayout.maxSide * 0.55)
      HStack(spacing: ImageGridLayout.spacing) {
        gridCell(path: paths[1])
        gridCell(path: paths[2])
        gridCell(path: paths[3])
        gridCell(path: paths[4])
      }
      .frame(height: ImageGridLayout.maxSide * 0.32)
    }
    .frame(width: ImageGridLayout.maxSide)
    .clipShape(
      RoundedRectangle(
        cornerRadius: ImageGridLayout.gridCornerRadius,
        style: .continuous
      )
    )
  }

  /// 5장 초과는 명세상 없음. 안전하게 첫 1장만 노출.
  @ViewBuilder
  private var fallbackLayout: some View {
    ChatImageView(
      path: paths.first,
      baseURL: baseURL,
      shape: .roundedRect(cornerRadius: ImageGridLayout.singleCornerRadius)
    )
    .frame(width: ImageGridLayout.maxSide, height: ImageGridLayout.maxSide)
  }

  // MARK: - Cell

  /// 그리드 내부 단일 셀. 외곽이 RoundedRectangle로 마스킹되므로 셀 자체는 직사각형.
  /// `ChatImageView`는 자체적으로 `maxWidth/maxHeight: .infinity`를 적용하므로
  /// 부모 HStack/VStack이 균등 분배한 셀을 자동으로 채운다.
  private func gridCell(path: String) -> some View {
    ChatImageView(
      path: path,
      baseURL: baseURL,
      shape: .roundedRect(cornerRadius: 0)
    )
  }
}

// MARK: - Layout constants

/// 카톡식 그리드 사이즈. 절대값을 한 곳에 모아 향후 디자인 토큰으로 승격하기 쉽게 한다.
private enum ImageGridLayout {
  static let maxSide: CGFloat = 220
  static let halfSide: CGFloat = 108
  static let spacing: CGFloat = 2
  static let singleCornerRadius: CGFloat = 14
  static let gridCornerRadius: CGFloat = 14
}
