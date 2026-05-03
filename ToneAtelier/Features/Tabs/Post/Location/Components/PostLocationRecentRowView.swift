//
//  PostLocationRecentRowView.swift
//  ToneAtelier
//
//  Created by Codex on 5/3/26.
//
//  Pencil node: GGlsI (recentLocationList)
//

import SwiftUI

struct PostLocationRecentListView: View {
  let recents: [PostLocationRecent]
  let onTap: (PostLocationRecent) -> Void

  var body: some View {
    if recents.isEmpty {
      EmptyView()
    } else {
      VStack(alignment: .leading, spacing: 8) {
        Text("최근 선택")
          .font(AppTheme.pretendard(size: 13, weight: .bold))
          .foregroundStyle(AppTheme.gray30)

        VStack(spacing: 0) {
          ForEach(recents) { recent in
            Button {
              onTap(recent)
            } label: {
              HStack(spacing: 8) {
                Image(systemName: "clock")
                  .font(AppTheme.symbol(size: 14, weight: .regular))
                  .foregroundStyle(AppTheme.gray60)

                Text(recent.displayText)
                  .font(AppTheme.pretendard(size: 12, weight: .semibold))
                  .foregroundStyle(AppTheme.gray60)
                  .lineLimit(1)
                  .truncationMode(.tail)

                Spacer(minLength: 0)
              }
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.vertical, 8)
              .padding(.horizontal, 12)
              .contentShape(.rect)
            }
            .buttonStyle(.plain)
          }
        }
        .background(AppTheme.blackTurquoise)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      }
    }
  }
}

#Preview {
  PostLocationRecentListView(
    recents: [
      PostLocationRecent(id: UUID(), latitude: 37.5263, longitude: 126.8924, address: "새싹 캠퍼스 · 서울 영등포구"),
      PostLocationRecent(id: UUID(), latitude: 37.5263, longitude: 126.9324, address: "한강공원 입구 · 서울 영등포구 여의동")
    ],
    onTap: { _ in }
  )
  .padding(20)
  .background(AppTheme.background)
  .preferredColorScheme(.dark)
}
