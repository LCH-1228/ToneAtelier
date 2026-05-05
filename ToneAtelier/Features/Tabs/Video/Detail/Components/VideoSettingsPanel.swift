//
//  VideoSettingsPanel.swift
//  ToneAtelier
//
//  Created by Codex on 5/5/26.
//

import SwiftUI

struct VideoSettingsPanel: View {
  let playbackRate: Float
  let qualities: [StreamQualityDTO]
  let selectedQuality: String?
  let onSpeedSelect: (Float) -> Void
  let onQualitySelect: (String?) -> Void

  @State private var expanded: Section?

  private enum Section: String { case speed, quality }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      speedSection
      Divider()
        .background(Color.white.opacity(0.18))
      qualitySection
    }
    .padding(16)
    .frame(width: 260)
    .glassEffect(.regular, in: .rect(cornerRadius: 16))
    .presentationCompactAdaptation(.popover)
  }

  // MARK: - Sections

  // SwiftUI DisclosureGroup spring 이 transaction 으로 안 꺼져 header Button + conditional 로 자체 구현.
  private var speedSection: some View {
    VStack(alignment: .leading, spacing: 0) {
      sectionHeaderButton(
        title: "속도",
        value: speedLabel(playbackRate),
        isExpanded: expanded == .speed
      ) {
        toggleSection(.speed)
      }
      if expanded == .speed {
        VStack(alignment: .leading, spacing: 4) {
          ForEach(VideoSpeedPicker.options, id: \.self) { rate in
            optionButton(
              title: speedLabel(rate),
              isSelected: abs(rate - playbackRate) < 0.01
            ) {
              onSpeedSelect(rate)
            }
          }
        }
        .padding(.top, 4)
      }
    }
  }

  private var qualitySection: some View {
    VStack(alignment: .leading, spacing: 0) {
      sectionHeaderButton(
        title: "화질",
        value: selectedQuality ?? "자동",
        isExpanded: expanded == .quality
      ) {
        toggleSection(.quality)
      }
      if expanded == .quality {
        VStack(alignment: .leading, spacing: 4) {
          optionButton(
            title: "자동",
            isSelected: selectedQuality == nil
          ) {
            onQualitySelect(nil)
          }
          ForEach(qualities, id: \.quality) { item in
            optionButton(
              title: item.quality,
              isSelected: selectedQuality == item.quality
            ) {
              onQualitySelect(item.quality)
            }
          }
        }
        .padding(.top, 4)
      }
    }
  }

  // MARK: - Helpers

  private func toggleSection(_ section: Section) {
    withAnimation(.default) {
      expanded = (expanded == section) ? nil : section
    }
  }

  private func sectionHeaderButton(
    title: String,
    value: String,
    isExpanded: Bool,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 8) {
        Text(title)
          .pretendard(.body2)
          .foregroundStyle(.white)
        Spacer(minLength: 0)
        Text(value)
          .pretendard(.caption2Bold)
          .foregroundStyle(.white.opacity(0.7))
        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.white.opacity(0.7))
      }
      .padding(.vertical, 6)
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
  }

  private func optionButton(
    title: String,
    isSelected: Bool,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack {
        Text(title)
          .pretendard(.body3)
          .foregroundStyle(.white)
        Spacer(minLength: 0)
        if isSelected {
          Image(systemName: "checkmark")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
        }
      }
      .padding(.vertical, 8)
      .padding(.horizontal, 8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
  }

  private func speedLabel(_ value: Float) -> String {
    String(format: "%.2gx", value)
  }
}
