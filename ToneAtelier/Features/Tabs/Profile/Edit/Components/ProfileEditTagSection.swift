//
//  ProfileEditTagSection.swift
//  ToneAtelier
//
//  Created by Codex on 5/1/26.
//

import SwiftUI

struct ProfileEditTagSection: View {
  let tags: [String]
  let addAction: () -> Void
  let removeAction: (String) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("해시태그")
        .pretendard(.body2)
        .foregroundStyle(AppTheme.gray60)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(tags, id: \.self) { tag in
            tagChip(tag: tag)
          }
          addChip
        }
      }
    }
  }

  private func tagChip(tag: String) -> some View {
    Button {
      removeAction(tag)
    } label: {
      HStack(spacing: 6) {
        Text(tag)
          .pretendard(.captionBold)
          .foregroundStyle(AppTheme.gray30)
        Image(systemName: "xmark.circle.fill")
          .font(AppTheme.symbol(size: 14, weight: .medium))
          .foregroundStyle(AppTheme.gray30)
      }
      .padding(.horizontal, 12)
      .frame(height: 28)
      .background(AppTheme.brightTurquoise)
      .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    .accessibilityLabel("\(tag) 삭제")
  }

  private var addChip: some View {
    Button(action: addAction) {
      Text("+ 추가")
        .pretendard(.captionBold)
        .foregroundStyle(AppTheme.gray60)
        .padding(.horizontal, 12)
        .frame(height: 28)
        .background(AppTheme.blackTurquoise)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(AppTheme.deepTurquoise, lineWidth: 1)
        }
    }
    .accessibilityLabel("해시태그 추가")
  }
}

#Preview {
  ProfileEditTagSection(
    tags: ["#맑음", "#차분"],
    addAction: {},
    removeAction: { _ in }
  )
  .padding()
  .background(AppTheme.background)
  .preferredColorScheme(.dark)
}
