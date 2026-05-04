//
//  MakeEditView.swift
//  ToneAtelier
//
//  Created by Codex on 4/28/26.
//

// swiftlint:disable file_length
// 메인 뷰 + 캔버스/슬라이더 sub-view + 트랙 그라디언트 helper가 한 화면 단위라 분리 인공적.

import ComposableArchitecture
import SwiftUI

struct MakeEditView: View {
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
    .background(AppTheme.background.ignoresSafeArea())
    .navigationBarBackButtonHidden(true)
    .toolbar(.hidden, for: .navigationBar)
  }

  private var navigationHeader: some View {
    HStack {
      SharedIconButton(
        accessibilityLabel: "뒤로 가기",
        action: {
          store.send(.backButtonTapped)
        },
        icon: {
          Image(systemName: "chevron.left")
            .font(AppTheme.symbol(size: 17, weight: .semibold))
            .foregroundStyle(AppTheme.gray75)
        }
      )

      Spacer()

      Text("EDIT")
        .mulgyeol(.bodyNormal)
        .foregroundStyle(AppTheme.gray60)

      Spacer()

      SharedIconButton(
        accessibilityLabel: "저장하기",
        isDisabled: !store.hasChanges
      ) {
        store.send(.saveButtonTapped)
      } icon: {
        Image(AppAsset.Make.save)
          .renderingMode(.template)
          .resizable()
          .scaledToFit()
          .foregroundStyle(store.hasChanges ? AppTheme.gray75 : AppTheme.gray60)
          .frame(width: 22, height: 22)
      }
    }
    .frame(height: 56)
    .padding(.horizontal, 4)
  }

  private func photoCanvas(width: CGFloat, height: CGFloat) -> some View {
    MakeEditPhotoCanvas(
      previewImageData: store.registeredPhoto.previewImageData,
      width: width,
      height: height,
      canUndo: store.canUndo,
      canRedo: store.canRedo,
      onUndoTapped: {
        store.send(.undoButtonTapped, animation: .easeInOut(duration: 0.16))
      },
      onRedoTapped: {
        store.send(.redoButtonTapped, animation: .easeInOut(duration: 0.16))
      }
    )
  }

  private func editControlPanel(width: CGFloat, height: CGFloat) -> some View {
    VStack(spacing: 0) {
      valueBubbleRow(parameter: store.selectedParameter)
        .padding(.top, 16)

      filterValueSlider(parameter: store.selectedParameter)
        .padding(.top, 8)
        .padding(.horizontal, 20)

      ScrollView(.horizontal) {
        HStack(spacing: 12) {
          ForEach(MakeFilterParameter.allCases) { parameter in
            lutItemView(parameter)
          }
        }
        .padding(.horizontal, 20)
      }
      .scrollIndicators(.hidden)
      .padding(.top, 26)
    }
    .frame(width: width, height: height, alignment: .top)
    .background(AppTheme.background)
    .clipped()
  }

  private func valueBubbleRow(parameter: MakeFilterParameter) -> some View {
    GeometryReader { proxy in
      let value = store.filterValues.value(for: parameter)
      let progress = sliderProgress(value: value, in: parameter.range)
      let bubbleWidth: CGFloat = parameter == .temperature ? 60 : 44
      let horizontalInset: CGFloat = 20
      let trackWidth = max(0, proxy.size.width - horizontalInset * 2)
      let rawX = horizontalInset + trackWidth * progress - bubbleWidth / 2
      let clampedX = min(max(0, rawX), max(0, proxy.size.width - bubbleWidth))

      Text(parameter.displayValue(value))
        .pretendard(.body2)
        .foregroundStyle(AppTheme.gray75)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(width: bubbleWidth, height: 20)
        .background(AppTheme.blackTurquoise)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .offset(x: clampedX)
    }
    .frame(height: 20)
  }

  private func filterValueSlider(parameter: MakeFilterParameter) -> some View {
    MakeFilterValueBar(
      parameter: parameter,
      value: store.filterValues.value(for: parameter),
      onEditingStarted: {
        store.send(.filterValueEditingStarted)
      },
      onValueChanged: { value in
        store.send(.filterValueChanged(parameter, value))
      },
      onEditingEnded: {
        store.send(.filterValueEditingEnded)
      }
    )
    .frame(height: 18)
  }

  private func lutItemView(_ parameter: MakeFilterParameter) -> some View {
    let isSelected = parameter == store.selectedParameter
    let isEdited = parameter.isEdited(value: store.filterValues.value(for: parameter))

    return Button {
      store.send(.parameterTapped(parameter), animation: .easeInOut(duration: 0.16))
    } label: {
      ZStack(alignment: .topTrailing) {
        VStack(spacing: 8) {
          Image(parameter.assetName)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(isSelected ? AppTheme.gray30 : AppTheme.gray75)
            .frame(width: 32, height: 32)

          Text(parameter.title)
            .pretendard(.caption2Bold)
            .foregroundStyle(isSelected ? AppTheme.gray30 : AppTheme.gray75)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(width: 62)
        }
        .frame(width: 62, height: 58)
        .padding(.vertical, 6)
        .background(isSelected ? AppTheme.blackTurquoise : Color.clear)
        .overlay {
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(isSelected ? AppTheme.deepTurquoise : Color.clear, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

        if isEdited {
          Circle()
            .fill(Color(hex: 0x0EC7A6))
            .frame(width: 6, height: 6)
            .padding(.top, 4)
            .padding(.trailing, 4)
        }
      }
      .frame(width: 62)
    }
    .buttonStyle(.plain)
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

  private func sliderProgress(
    value: Double,
    in range: ClosedRange<Double>
  ) -> Double {
    let span = range.upperBound - range.lowerBound
    guard span > 0 else { return 0 }
    let progress = (value - range.lowerBound) / span
    return min(max(progress, 0), 1)
  }
}

private struct MakeEditPhotoCanvas: View {
  // TODO: LUTItem 수정값 기반 이미지 렌더링 연결 필요

  @State private var image: UIImage?

  let previewImageData: Data
  let width: CGFloat
  let height: CGFloat
  let canUndo: Bool
  let canRedo: Bool
  let onUndoTapped: () -> Void
  let onRedoTapped: () -> Void

  init(
    previewImageData: Data,
    width: CGFloat,
    height: CGFloat,
    canUndo: Bool,
    canRedo: Bool,
    onUndoTapped: @escaping () -> Void,
    onRedoTapped: @escaping () -> Void
  ) {
    self.previewImageData = previewImageData
    self.width = width
    self.height = height
    self.canUndo = canUndo
    self.canRedo = canRedo
    self.onUndoTapped = onUndoTapped
    self.onRedoTapped = onRedoTapped
  }

  var body: some View {
    ZStack(alignment: .bottom) {
      if let image {
        Image(uiImage: image)
          .resizable()
          .scaledToFill()
          .frame(width: width, height: height)
          .clipped()
          .transaction { transaction in
            transaction.animation = nil
          }
      } else {
        Rectangle()
          .fill(AppTheme.blackTurquoise)
          .frame(width: width, height: height)
      }

      HStack {
        HStack(spacing: 8) {
          editToolButton(
            systemName: "arrow.uturn.backward",
            isEnabled: canUndo,
            action: onUndoTapped
          )
          editToolButton(
            systemName: "arrow.uturn.forward",
            isEnabled: canRedo,
            action: onRedoTapped
          )
        }

        Spacer()

        editToolButton(systemName: "rectangle.split.2x1")
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 16)
    }
    .frame(width: width, height: height)
    .clipped()
    .task {
      guard image == nil else { return }
      image = UIImage(data: previewImageData)
    }
  }

  private func editToolButton(
    systemName: String,
    isEnabled: Bool = true,
    action: @escaping () -> Void = {}
  ) -> some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(AppTheme.symbol(size: 18, weight: .semibold))
        .foregroundStyle(AppTheme.gray45)
        .frame(width: 40, height: 32)
        .background(AppTheme.gray75.opacity(0.5))
        .overlay {
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(AppTheme.gray75.opacity(0.5), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .opacity(isEnabled ? 1 : 0.35)
    }
    .buttonStyle(.plain)
    .disabled(!isEnabled)
  }
}

private struct MakeFilterValueBar: View {
  @State private var isEditing = false

  let parameter: MakeFilterParameter
  let value: Double
  let onEditingStarted: () -> Void
  let onValueChanged: (Double) -> Void
  let onEditingEnded: () -> Void

  var body: some View {
    GeometryReader { proxy in
      let width = max(1, proxy.size.width)
      let progress = sliderProgress(value: value, in: parameter.range)
      let defaultProgress = sliderProgress(value: parameter.defaultValue, in: parameter.range)
      let thumbX = width * progress
      let defaultX = width * defaultProgress

      ZStack(alignment: .leading) {
        Capsule()
          .fill(AppTheme.blackTurquoise)
          .frame(height: 12)

        Capsule()
          .fill(parameter.trackGradient)
          .frame(height: 12)
          .overlay {
            Capsule()
              .stroke(AppTheme.deepTurquoise.opacity(0.85), lineWidth: 1)
          }
          .clipShape(Capsule())

        Rectangle()
          .fill(AppTheme.gray30.opacity(0.9))
          .frame(width: 2, height: 18)
          .offset(x: min(max(defaultX - 1, 0), width - 2))
          .opacity(parameter.defaultValue == parameter.range.lowerBound ? 0 : 1)

        Circle()
          .fill(Color(hex: 0x0EC7A6))
          .frame(width: 10, height: 10)
          .overlay {
            Circle()
              .stroke(AppTheme.background, lineWidth: 2)
          }
          .offset(x: min(max(thumbX - 5, 0), width - 10), y: 1)
      }
      .frame(height: 18)
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { gesture in
            if !isEditing {
              isEditing = true
              onEditingStarted()
            }
            let progress = min(max(gesture.location.x / width, 0), 1)
            let rawValue = parameter.range.lowerBound
              + (parameter.range.upperBound - parameter.range.lowerBound) * progress
            onValueChanged(parameter.steppedValue(rawValue))
          }
          .onEnded { _ in
            isEditing = false
            onEditingEnded()
          }
      )
    }
  }

  private func sliderProgress(
    value: Double,
    in range: ClosedRange<Double>
  ) -> Double {
    let span = range.upperBound - range.lowerBound
    guard span > 0 else { return 0 }
    return min(max((value - range.lowerBound) / span, 0), 1)
  }
}

private struct EditLayout {
  let width: CGFloat
  let height: CGFloat
  let photoHeight: CGFloat
  let controlHeight: CGFloat
}

private extension MakeFilterParameter {
  var trackGradient: LinearGradient {
    LinearGradient(
      colors: trackColors,
      startPoint: .leading,
      endPoint: .trailing
    )
  }

  var trackColors: [Color] {
    switch self {
    case .brightness:
      return [
        Color(hex: 0x111111),
        Color(hex: 0x777777),
        Color(hex: 0xFFFFFF)
      ]
    case .exposure:
      return [
        Color(hex: 0x050505),
        Color(hex: 0x315C6B),
        Color(hex: 0xF9F9F9)
      ]
    case .contrast:
      return [
        Color(hex: 0x6A6A6E),
        Color(hex: 0x1F2527),
        Color(hex: 0xF9F9F9)
      ]
    case .saturation:
      return [
        Color(hex: 0x434347),
        Color(hex: 0xFF1DB9),
        Color(hex: 0x0EC7A6)
      ]
    case .sharpness:
      return [
        Color(hex: 0x1F2527),
        Color(hex: 0xABABAE),
        Color(hex: 0xF9F9F9)
      ]
    case .blur:
      return [
        Color(hex: 0xF9F9F9),
        Color(hex: 0x6A6A6E),
        Color(hex: 0x1F2527)
      ]
    case .vignette:
      return [
        Color(hex: 0x0B0B0B),
        Color(hex: 0x315C6B),
        Color(hex: 0x0B0B0B)
      ]
    case .noiseReduction:
      return [
        Color(hex: 0x6A6A6E),
        Color(hex: 0x293235),
        Color(hex: 0x1F2527)
      ]
    case .highlights:
      return [
        Color(hex: 0x1F2527),
        Color(hex: 0xABABAE),
        Color(hex: 0xFFFFFF)
      ]
    case .shadows:
      return [
        Color(hex: 0x0B0B0B),
        Color(hex: 0x293235),
        Color(hex: 0xABABAE)
      ]
    case .temperature:
      return [
        Color(hex: 0x4A7DFF),
        Color(hex: 0xF9F9F9),
        Color(hex: 0xFF9B2F)
      ]
    case .blackPoint:
      return [
        Color(hex: 0x000000),
        Color(hex: 0x1F2527),
        Color(hex: 0x6A6A6E)
      ]
    }
  }
}

#Preview {
  NavigationStack {
    MakeEditView(
      store: Store(
        initialState: MakeEditFeature.State(
          registeredPhoto: MakeFeature.RegisteredPhoto(
            imageFileURL: URL(fileURLWithPath: "/dev/null"),
            previewImageData: Data(),
            thumbnailImageData: Data(),
            exif: MakeFeature.ExifInfo(
              deviceLine: "iPhone",
              cameraLine: "Wide Camera",
              fileLine: "Preview",
              locationLine: nil
            ),
            metadata: MakePhotoMetadata(fileSize: 0)
          )
        )
      ) {
        MakeEditFeature()
      }
    )
  }
}
