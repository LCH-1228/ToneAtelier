//
//  MakeEditView.swift
//  ToneAtelier
//
//  Created by Codex on 4/28/26.
//

import ComposableArchitecture
import SwiftUI
import UIKit

struct MakeEditView: View {
  @Environment(\.dismiss) private var dismiss

  let store: StoreOf<MakeEditFeature>

  var body: some View {
    GeometryReader { proxy in
      let layout = editLayout(for: proxy.size)

      VStack(spacing: 0) {
        navigationHeader

        photoCanvas(width: layout.width, height: layout.photoHeight)

        editControlPanel(width: layout.width, height: layout.controlHeight)
      }
      .frame(width: layout.width, height: layout.height, alignment: .top)
      .clipped()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(HomeTheme.background.ignoresSafeArea())
    .navigationBarBackButtonHidden(true)
    .toolbar(.hidden, for: .navigationBar)
  }

  private var navigationHeader: some View {
    HStack {
      SharedIconButton(
        accessibilityLabel: "뒤로 가기",
        action: { dismiss() }
      ) {
        Image(systemName: "chevron.left")
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(HomeTheme.gray75)
      }

      Spacer()

      Text("EDIT")
        .font(HomeTheme.mulgyeol(size: 20, weight: .bold))
        .foregroundStyle(HomeTheme.gray60)

      Spacer()

      SharedIconButton(accessibilityLabel: "저장하기") {
      } icon: {
        Image(AppAsset.Make.save)
          .renderingMode(.template)
          .resizable()
          .scaledToFit()
          .foregroundStyle(HomeTheme.gray75)
          .frame(width: 22, height: 22)
      }
    }
    .frame(height: 56)
    .padding(.horizontal, 4)
  }

  private func photoCanvas(width: CGFloat, height: CGFloat) -> some View {
    ZStack(alignment: .bottom) {
      if let image = UIImage(data: store.registeredPhoto.imageData) {
        Image(uiImage: image)
          .resizable()
          .scaledToFill()
          .frame(width: width, height: height)
          .clipped()
      } else {
        Rectangle()
          .fill(HomeTheme.blackTurquoise)
          .frame(width: width, height: height)
      }

      HStack {
        HStack(spacing: 8) {
          editToolButton(systemName: "arrow.uturn.backward")
          editToolButton(systemName: "arrow.uturn.forward")
        }

        Spacer()

        editToolButton(systemName: "rectangle.split.2x1")
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 16)
    }
    .frame(width: width, height: height)
    .clipped()
  }

  private func editControlPanel(width: CGFloat, height: CGFloat) -> some View {
    VStack(spacing: 0) {
      valueBubbleRow
        .padding(.top, 16)

      staticSlider
        .padding(.top, 8)
        .padding(.horizontal, 20)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
          ForEach(lutItems) { item in
            lutItemView(item)
          }
        }
        .padding(.horizontal, 20)
      }
      .padding(.top, 26)
    }
    .frame(width: width, height: height, alignment: .top)
    .background(HomeTheme.background)
    .clipped()
  }

  private var valueBubbleRow: some View {
    GeometryReader { proxy in
      let progress = 0.71
      let bubbleWidth: CGFloat = 44
      let horizontalInset: CGFloat = 20
      let trackWidth = max(0, proxy.size.width - horizontalInset * 2)
      let rawX = horizontalInset + trackWidth * progress - bubbleWidth / 2
      let clampedX = min(max(0, rawX), max(0, proxy.size.width - bubbleWidth))

      Text("3.4")
        .font(HomeTheme.pretendard(size: 14, weight: .bold))
        .foregroundStyle(HomeTheme.gray75)
        .frame(width: bubbleWidth, height: 20)
        .background(HomeTheme.blackTurquoise)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .offset(x: clampedX)
    }
    .frame(height: 20)
  }

  private var staticSlider: some View {
    GeometryReader { proxy in
      let width = proxy.size.width
      let progress = 0.71

      ZStack(alignment: .leading) {
        Capsule()
          .fill(HomeTheme.blackTurquoise)
          .frame(height: 12)

        Capsule()
          .fill(
            LinearGradient(
              colors: [
                Color(hex: 0xFF1DB9),
                Color(hex: 0x30B9AA)
              ],
              startPoint: .leading,
              endPoint: .trailing
            )
          )
          .frame(width: width * progress, height: 12)

        Circle()
          .fill(Color(hex: 0x0EC7A6))
          .frame(width: 6, height: 6)
          .offset(x: width * progress - 3)

        Circle()
          .fill(HomeTheme.gray75.opacity(0.35))
          .frame(width: 3, height: 3)
          .offset(x: width * 0.88)
      }
    }
    .frame(height: 12)
  }

  private func editToolButton(systemName: String) -> some View {
    Button {
    } label: {
      Image(systemName: systemName)
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(HomeTheme.gray45)
        .frame(width: 40, height: 32)
        .background(HomeTheme.gray75.opacity(0.5))
        .overlay {
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(HomeTheme.gray75.opacity(0.5), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  private func lutItemView(_ item: LUTItem) -> some View {
    VStack(spacing: 8) {
      Image(item.assetName)
        .renderingMode(.template)
        .resizable()
        .scaledToFit()
        .foregroundStyle(item.isSelected ? HomeTheme.gray30 : HomeTheme.gray75)
        .frame(width: 32, height: 32)

      Text(item.title)
        .font(HomeTheme.pretendard(size: 10, weight: .semibold))
        .foregroundStyle(item.isSelected ? HomeTheme.gray30 : HomeTheme.gray75)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .frame(width: 62)
    }
    .frame(width: 62)
  }

  private var lutItems: [LUTItem] {
    [
      LUTItem(title: "BRIGHTNESS", assetName: AppAsset.HomeDetail.presetBrightness),
      LUTItem(title: "EXPOSURE", assetName: AppAsset.HomeDetail.presetExposure),
      LUTItem(title: "CONTRAST", assetName: AppAsset.HomeDetail.presetContrast),
      LUTItem(title: "SATURATION", assetName: AppAsset.HomeDetail.presetSaturation, isSelected: true),
      LUTItem(title: "SHARPNESS", assetName: AppAsset.HomeDetail.presetSharpness),
      LUTItem(title: "BLUR", assetName: AppAsset.HomeDetail.presetBlur),
      LUTItem(title: "VIGNETTE", assetName: AppAsset.HomeDetail.presetVignette),
      LUTItem(title: "NOISE", assetName: AppAsset.HomeDetail.presetNoise),
      LUTItem(title: "HIGHLIGHTS", assetName: AppAsset.HomeDetail.presetHighlights),
      LUTItem(title: "SHADOWS", assetName: AppAsset.HomeDetail.presetShadows),
      LUTItem(title: "TEMPERATURE", assetName: AppAsset.HomeDetail.presetTemperature),
      LUTItem(title: "BLACKPOINT", assetName: AppAsset.HomeDetail.presetBlackPoint)
    ]
  }

  private func editLayout(for size: CGSize) -> EditLayout {
    let headerHeight: CGFloat = 56
    let preferredControlHeight: CGFloat = 156
    let minimumControlHeight: CGFloat = 120
    let height = max(0, size.height)
    let availableHeight = max(0, height - headerHeight)
    let proposedControlHeight = availableHeight > 560
      ? preferredControlHeight
      : max(minimumControlHeight, availableHeight * 0.24)
    let controlHeight = min(proposedControlHeight, availableHeight)
    let photoHeight = max(0, availableHeight - controlHeight)

    return EditLayout(
      width: max(0, size.width),
      height: height,
      photoHeight: photoHeight,
      controlHeight: controlHeight
    )
  }
}

private struct EditLayout {
  let width: CGFloat
  let height: CGFloat
  let photoHeight: CGFloat
  let controlHeight: CGFloat
}

private struct LUTItem: Identifiable {
  let title: String
  let assetName: String
  var isSelected = false

  var id: String { title }
}

#Preview {
  NavigationStack {
    MakeEditView(
      store: Store(
        initialState: MakeEditFeature.State(
          registeredPhoto: MakeFeature.RegisteredPhoto(
            imageData: Data(),
            exif: MakeFeature.ExifInfo(
              deviceLine: "iPhone",
              cameraLine: "Wide Camera",
              fileLine: "Preview",
              locationLine: nil
            )
          )
        )
      ) {
        MakeEditFeature()
      }
    )
  }
}
