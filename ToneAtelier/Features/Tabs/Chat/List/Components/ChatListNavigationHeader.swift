import SwiftUI

struct ChatListNavigationHeader: View {
  let searchEntryAction: () -> Void

  var body: some View {
    HStack(spacing: 0) {
      Color.clear.frame(width: 48, height: 48)
      Spacer()
      Text("CHAT")
        .mulgyeol(.bodyNormal)
        .foregroundStyle(AppTheme.gray60)
        .accessibilityAddTraits(.isHeader)
      Spacer()
      Button(action: searchEntryAction) {
        Image(systemName: "person.crop.circle.badge.magnifyingglass")
          .font(AppTheme.symbol(size: 22, weight: .regular))
          .foregroundStyle(AppTheme.gray30)
          .frame(width: 48, height: 48)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("사용자 검색")
    }
    .frame(height: 56)
    .padding(.horizontal, 4)
  }
}

#Preview {
  ChatListNavigationHeader(searchEntryAction: {})
    .background(AppTheme.background)
    .preferredColorScheme(.dark)
}
