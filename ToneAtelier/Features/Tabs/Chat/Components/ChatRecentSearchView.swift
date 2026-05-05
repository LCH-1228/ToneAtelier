import SwiftUI

struct ChatRecentSearchView: View {
  let keywords: [String]
  let onTap: (String) -> Void
  let onClearAll: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("최근 검색")
          .pretendard(.body3Bold)
          .foregroundStyle(AppTheme.gray30)
        Spacer()
        Button(action: onClearAll) {
          Text("전체삭제")
            .pretendard(.body3)
            .foregroundStyle(AppTheme.gray60)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("최근 검색 전체 삭제")
      }
      .padding(.horizontal, 20)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(keywords, id: \.self) { keyword in
            Button {
              onTap(keyword)
            } label: {
              Text(keyword)
                .pretendard(.body3)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(AppTheme.blackTurquoise))
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.horizontal, 20)
      }
    }
    .padding(.vertical, 12)
  }
}

#Preview {
  ChatRecentSearchView(
    keywords: ["윤새싹", "김새싹", "이새싹"],
    onTap: { _ in },
    onClearAll: {}
  )
  .background(AppTheme.background)
  .preferredColorScheme(.dark)
}
