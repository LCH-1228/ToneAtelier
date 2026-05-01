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
  let removeAction: (Int) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("해시태그")
        .font(AppTheme.pretendard(size: 14, weight: .bold))
        .foregroundStyle(AppTheme.gray60)

      // 본 단계는 horizontal scroll 행으로 단순화. 칩이 늘어나면 자동으로 가로 스크롤.
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(Array(tags.enumerated()), id: \.offset) { index, tag in
            tagChip(tag: tag, index: index)
          }
          addChip
        }
      }
    }
  }

  private func tagChip(tag: String, index: Int) -> some View {
    Button {
      removeAction(index)
    } label: {
      HStack(spacing: 6) {
        Text(tag)
          .font(AppTheme.pretendard(size: 12, weight: .bold))
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
        .font(AppTheme.pretendard(size: 12, weight: .bold))
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
